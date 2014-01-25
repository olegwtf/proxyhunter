package App::ProxyHunter;

use strict;
use Coro::Select;
use Coro::LWP;
use Coro::Timer;
use Coro::Util;
use Coro::PatchSet;
use Coro;
use LWP::UserAgent;
use LWP::Protocol::https;
use LWP::Protocol::connect;
use LWP::Protocol::socks;
use Net::Proxy::Type ':types';
use Carp;
use Time::HiRes;
use DateTime;
use List::Util 'shuffle';
use Getopt::Long;
use App::ProxyHunter::Constants;
use App::ProxyHunter::Config;
use App::ProxyHunter::Model;

use constant CORO_DELAY       => 5;
use constant SELECT_LIMIT     => 100;
use constant MAX_SEC_IN_QUEUE => 60;

our $VERSION = '0.01';

sub start {
	my $class = shift;
	my $opts_ok = Getopt::Long::Parser->new->getoptionsfromarray(
		\@_,
		'create-config=s' => \my $create_config,
		'create-schema'   => \my $create_schema,
		'config=s'        => \my $config,
		'daemon:s'        => \my $daemon
	);
	
	my $usage = "usage: $0 --create-config /path/to/config | --config /path/to/config --create-schema | --config /path/to/config [--daemon [/path/to/pidfile]]\n";
	
	unless ($opts_ok) {
		die $usage;
	}
	
	if (defined $create_config) {
		open my $fh, '>', $create_config
			or croak "can't open `$create_config' for write: $!";
		
		while (my $str = <DATA>) {
			print $fh $str;
		}
		
		close $fh;
		return;
	}
	
	unless (defined $config) {
		die $usage;
	}
	
	$config = App::ProxyHunter::Config->new(path => $config);
	
	my $model = App::ProxyHunter::Model->new(
		connect_info => [
			sprintf('dbi:%s:database=%s', $config->db->driver, $config->db->name) .
				($config->db->host ? ';host='.$config->db->host : ''),
			$config->db->login,
			$config->db->password,
			{
				%{$config->db->driver_cfg},
				AutoInactiveDestroy => 1
			}
		],
		schema_class => 'App::ProxyHunter::Model::Schema::' . $config->db->driver
	);
	
	if (defined $create_schema) {
		while (my $query = $model->schema_class->get_create_query()) {
			$model->do($query);
		}
		return;
	}
	
	for my $engine (@{$config->searcher->engines}) {
		$engine = 'App::ProxyHunter::SearchEngine::'.$engine;
		eval "require $engine"
			or croak "Can't load search engine module $engine: $@";
	}
	
	if (defined $daemon) {
		$SIG{INT} = $SIG{TERM} = sub {
			unlink $daemon if length($daemon) > 0;
			exit;
		};
		
		eval {
			require Proc::Daemon;
		};
		if ($@) {
			croak 'You need to install Proc::Daemon to perform daemonization: ', $@;
		}
		
		Proc::Daemon::Init({
			work_dir => '.',
			length($daemon)>0 ? (pid_file => $daemon) : ()
		});
	}
	
	$model->update('proxy', {in_progress => 0}); # clean
	
	my @coros;
	if ($config->checker->enabled) {
		push @coros, $class->_start_checkers($config, $model);
	}
	if ($config->rechecker->enabled) {
		push @coros, $class->_start_recheckers($config, $model);
	}
	if ($config->speed_checker->enabled) {
		push @coros, $class->_start_speed_checkers($config, $model);
	}
	if ($config->searcher->enabled) {
		push @coros, $class->_start_searcher($config, $model);
	}
	
	$_->join() for @coros;
}

sub _start_checkers {
	my ($class, $config, $model) = @_;
	
	my @coros;
	my @queue;
	my $delay;
	
	for (1..$config->checker->workers) {
		push @coros, async {
			my $type_checker = Net::Proxy::Type->new(http_strict => 1, noauth => 1);
			my $speed_checker = $config->checker->speed_check ?
				LWP::UserAgent->new(agent => 'Mozilla 5.0', timeout => 10, parse_head => 0) :
				undef;
			
			while (1) {
				unless (@queue) {
					if ($delay) {
						Coro::Timer::sleep $delay;
						next;
					}
					
					unless (@queue = $class->_get_queue($model, {checked => 0}, {order_by => 'checkdate'})) {
						$delay = CORO_DELAY;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
				}
				
				my $proxy = shift @queue;
				my ($type, $conn_time) = $class->_check($type_checker, $proxy)
					or do {
						$proxy->delete();
						next;
					};
				
				$proxy->set('type', $type);
				$proxy->set('conn_time', $conn_time);
				
				if ($speed_checker) {
					my $speed = $class->_check_speed($speed_checker, $config->speed_checker, $proxy)
						or do {
							$proxy->delete();
							next;
						};
					
					$proxy->set('speed', $speed);
					$proxy->set('speed_checkdate', DateTime->now(time_zone => TZ));
				}
				
				$proxy->set('checked', 1);
				$proxy->set('checkdate', DateTime->now(time_zone => TZ));
				$proxy->set('in_progress', \0); # force update
				$proxy->set('success_total', 1);
				$proxy->update();
			}
		}
	}
	
	return @coros;
}

sub _start_recheckers {
	my ($class, $config, $model) = @_;
	
	my @coros;
	my @queue;
	my $delay;
	
	for (1..$config->rechecker->workers) {
		push @coros, async {
			my $type_checker = Net::Proxy::Type->new(http_strict => 1, noauth => 1);
			my $speed_checker = $config->rechecker->speed_check ?
				LWP::UserAgent->new(agent => 'Mozilla 5.0', timeout => 10, parse_head => 0) :
				undef;
			
			while (1) {
				if ($delay) {
					Coro::Timer::sleep $delay;
					next;
				}
				
				unless (@queue) {
					unless (@queue = $class->_get_queue($model, {checked => 1}, {order_by => 'checkdate'})) {
						$delay = CORO_DELAY;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
					
					my $sec_after_last_check = DateTime->now(time_zone => TZ)->
							subtract_datetime_absolute($queue[0]->checkdate)->seconds;
					
					if ($sec_after_last_check < $config->rechecker->interval) {
						$delay = $config->rechecker->interval - $sec_after_last_check;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
				}
				
				my $proxy = shift @queue;
				my $fail;
				if (my ($type, $conn_time) = $class->_check($type_checker, $proxy)) {
					$proxy->set('type', $type);
					$proxy->set('conn_time', $conn_time);
					
					if ($speed_checker) {
						if (my $speed = $class->_check_speed($speed_checker, $config->speed_checker, $proxy)) {
							$proxy->set('speed', $speed);
						}
						else {
							$fail = 1;
							$proxy->set('speed', 0);
						}
						
						$proxy->set('speed_checkdate', DateTime->now(time_zone => TZ));
					}
				}
				else {
					$fail = 1;
				}
				
				if ($fail) {
					$proxy->set('fails_total', $proxy->fails_total+1);
					$proxy->set('fails', $proxy->fails+1);
					if ($proxy->fails > $config->rechecker->fails_before_delete) {
						$proxy->delete();
						next;
					}
				}
				else {
					$proxy->set('fails', 0);
					$proxy->set('success_total', $proxy->success_total+1);
				}
				
				$proxy->set('checkdate', DateTime->now(time_zone => TZ));
				$proxy->set('in_progress', \0); # force update
				$proxy->update();
			}
		}
	}
	
	return @coros;
}

sub _start_speed_checkers {
	my ($class, $config, $model) = @_;
	
	my @coros;
	my @queue;
	my $delay;
	
	for (1..$config->speed_checker->workers) {
		push @coros, async {
			my $speed_checker = LWP::UserAgent->new(agent => 'Mozilla 5.0', timeout => 10, parse_head => 0);
			
			while (1) {
				if ($delay) {
					Coro::Timer::sleep $delay;
					next;
				}
				
				unless (@queue) {
					unless (@queue = $class->_get_queue(
								$model,
								{checked => 1},
								{order_by => 'speed_checkdate'},
								$config->speed_checker->interval)) {
						
						$delay = CORO_DELAY;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
					
					my $sec_after_last_check = DateTime->now(time_zone => TZ)->
							subtract_datetime_absolute($queue[0]->speed_checkdate)->seconds;
					
					if ($sec_after_last_check < $config->speed_checker->interval) {
						$delay = $config->speed_checker->interval - $sec_after_last_check;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
				}
				
				my $proxy = shift @queue;
				if (my $speed = $class->_check_speed($speed_checker, $config->speed_checker, $proxy)) {
					$proxy->set('speed', $speed);
					$proxy->set('success_total', $proxy->success_total+1);
				}
				else {
					$proxy->set('fails', $proxy->fails+1);
					if ($proxy->fails > $config->rechecker->fails_before_delete) {
						$proxy->delete();
						next;
					}
					$proxy->set('speed', 0);
					$proxy->set('fails_total', $proxy->fails_total+1);
				}
				
				my $now = DateTime->now(time_zone => TZ);
				$proxy->set('checkdate', $now);
				$proxy->set('speed_checkdate', $now);
				$proxy->set('in_progress', \0); # force update
				$proxy->update();
			}
		}
	}
}

sub _start_searcher {
	my ($class, $config, $model) = @_;
	
	async {
		while (1) {
			my @querylist = shuffle @{$config->searcher->querylist};
			
			my @engines;
			my $i = 0;
			for my $engine (@{$config->searcher->engines}) {
				push @engines, $engine->new(query => $querylist[$i++ % @querylist]);
			}
			
			my $proxylist;
			while (@engines) {
				for ($i=$#engines; $i>=0; $i--) {
					unless ($proxylist = $engines[$i]->next) {
						splice @engines, $i, 1;
						next;
					}
					
					if (@$proxylist) {
						my $now = DateTime->now(time_zone => TZ);
						
						for my $proxy (@$proxylist) {
							my ($host, $port) = split /:/, $proxy;
							$host = Coro::Util::inet_aton($host) or next;
							$host = join('.', unpack('C4', $host));
							eval {
								# ignore duplicates
								$model->fast_insert('proxy', {
									host       => $host,
									port       => $port,
									insertdate => $now
								});
							}
						}
					}
				}
			}
		}
	}
}

sub _get_queue {
	my ($class, $model, $conditions, $rules, $interval) = @_;
	
	$conditions->{in_progress} = 0;
	$rules->{limit} = SELECT_LIMIT;
	
	my $iter = $model->search('proxy', $conditions, $rules);
	my $now = DateTime->now(time_zone => TZ);
	my $date_column = $rules->{order_by};
	
	my @rows;
	my @ids;
	
	while (my $proxy = $iter->next) {
		if (defined $interval && 
			$interval - $now->subtract_datetime_absolute($proxy->$date_column)->seconds > MAX_SEC_IN_QUEUE) {
			
			next;
		}
		
		push @rows, $proxy;
		push @ids, $proxy->id;
	}
	
	if (@ids) {
		$model->update('proxy', {in_progress => 1}, {id => \@ids});
	}
	
	return @rows;
}

sub _check {
	my ($class, $checker, $proxy) = @_;
	
	my $full_mask = 0;
	$full_mask |= $_ for grep { $_ != UNKNOWN_PROXY && $_ != DEAD_PROXY } keys %Net::Proxy::Type::NAME;
	my @check_mask;
	
	if ($proxy->type) {
		# first check for previous type of the proxy to speed up
		push @check_mask, $proxy->type;
		push @check_mask, $full_mask&(~$proxy->type);
	}
	else {
		push @check_mask, $full_mask;
	}
	
	for my $mask (@check_mask) {
		my ($type, $conn_time) = $checker->get($proxy->host, $proxy->port, $mask);
		
		unless ($type == DEAD_PROXY || $type == UNKNOWN_PROXY) {
			return ($type, $conn_time);
		}
	}
	
	return;
}

my %uri_scheme = (
	&HTTP_PROXY    => 'http',
	&CONNECT_PROXY => 'connect',
	&HTTPS_PROXY   => 'connect',
	&SOCKS4_PROXY  => 'socks4',
	&SOCKS5_PROXY  => 'socks',
);

sub _check_speed {
	my ($class, $checker, $config, $proxy) = @_;
	
	$checker->proxy(['http', 'https'] => sprintf('%s://%s:%s', $uri_scheme{$proxy->type}, $proxy->host, $proxy->port));
	
	my @speed_variations;
	my $received_bytes = 0;
	my $curspeed;
	my $maxbytes = 1024*1024;
	my $start = Time::HiRes::time();
	
	my $resp = $checker->get(
		$proxy->type == HTTPS_PROXY ? $config->https_url : $config->http_url,
		':content_cb' => sub {
			$received_bytes += length($_[0]);
			$curspeed = $received_bytes / (Time::HiRes::time() - $start);
			die if $received_bytes > $maxbytes;
			
			if (@speed_variations == 10) {
				my $ok = 1;
				for my $sv (@speed_variations) {
					if (abs($sv - $curspeed) > 5 * 1024) {
						$ok = 0;
						last;
					}
				}
				
				die if $ok;
				shift @speed_variations;
			}
			
			push @speed_variations, $curspeed;
		}
	);
	
	return if $resp->code > 299;
	return int($curspeed);
}

1;

=pod

=head1 NAME

App::ProxyHunter - main proxyhunter's class

=head1 METHODS

=head2 App::ProxyHunter->start(@ARGV)

Static method to start C<proxyhunter> execution. @ARGV is a list with options which C<proxyhunter> understands.

=head1 SEE ALSO

L<proxyhunter>

=head1 AUTHOR

Oleg G, E<lt>oleg@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself

=cut

__DATA__
db = {
	driver: "SQLite",
	driver_cfg: {},
	host: "localhost",
	name: "proxyhunter.db"
	login: "",
	password: ""
}

# first check
check = {
	enabled: true,
	workers: 30,
	speed_check: true # do immediate speed check
	                  # if true will performe speed check
	                  # even if speed_check.enabled is false
}

# recheck for alive proxies
recheck = {
	enabled: true,
	workers: 10,
	interval: 300,
	speed_check: false,
	fails_before_delete: 3 # if proxy was alive once
                           # how many times (in a row) its check may fail
                           # before it will be deleted from db
}

speed_check = {
	enabled: true,
	workers: 10,
	interval: 1800,
	http_url: "http://mirror.yandex.ru/debian/ls-lR.gz" # should be > 1 mb
	https_url: "https://mail.ru"
}


search = {
	enabled: true,
	# which queries to use when searching for proxylist
	# via google and other search engines
	querylist: [
		"proxy list",
		"socks proxy list",
		"socks5 proxy",
		"socks4 proxy",
		"free proxy list"
	],
	# which search engines to use
	# should be in App::ProxyHunter::SearchEngine:: namespace
	engines: [
		"Google", "Bing", "Yandex"
	]
}
