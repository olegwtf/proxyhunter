package App::ProxyHunter;

use strict;
use Coro::Select;
use Coro::LWP;
use Coro::Timer;
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
use Getopt::Long;
use App::ProxyHunter::Config;
use App::ProxyHunter::Model;

use constant CORO_DELAY => 5;

sub start {
	my $class = shift;
	my $opts_ok = Getopt::Long::Parser->new->getoptionsfromarray(
		\@_,
		'make-config=s' => \my $make_config,
		'config=s'      => \my $config,
		'daemon:s'      => \my $daemon
	);
	
	my $usage = "usage: $0 --make-config /path/to/config | --config /path/to/config [--daemon [/path/to/pidfile]]";
	
	unless ($opts_ok) {
		croak $usage;
	}
	
	if (defined $make_config) {
		open my $fh, '>', $make_config
			or croak "can't open `$make_config' for write: $!";
		
		while (my $str = <DATA>) {
			print $fh $str;
		}
		
		close $fh;
		return;
	}
	
	unless (defined $config) {
		croak $usage;
	}
	
	$config = App::ProxyHunter::Config->new(path => $config);
	
	my $model = App::ProxyHunter::Model->new(
		connect_info => [
			sprintf('dbi:%s:database=%s', $config->db->driver, $config->db->schema) .
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
	
	if (defined $daemon) {
		eval {
			require Proc::Daemon;
		};
		if ($@) {
			croak 'You need to install Proc::Daemon to perform daemonization: ', $@;
		}
		
		Proc::Daemon::Init({
			length($daemon)>0 ? (pid_file => $daemon) : ()
		});
	}
	
	$model->update('proxy', {in_progress => 0}); # clean
	my @coros;
	
	push @coros, $class->_start_checkers($config, $model);
	push @coros, $class->_start_recheckers($config, $model);
	
	if ($config->speed_checker->enabled) {
		push @coros, $class->_start_speed_checkers($config, $model);
	}
	
	push @coros, $class->_start_searcher($config, $model);
	
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
				LWP::UserAgent->new(agent => 'Mozilla 5.0', timeout => 10) :
				undef;
			
			while (1) {
				unless (@queue) {
					if ($delay) {
						Coro::Timer::sleep $delay;
						next;
					}
					
					unless (@queue = $class->_get_queue({checked => 0}, {order_by => 'check_date'})) {
						$delay = CORO_DELAY;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
				}
				
				my $proxy = shift @queue;
				my ($type, $conn_time) = $class->_check($type_checker, $proxy)
					or do {
						$proxy->delelete();
						next;
					};
				
				$proxy->type($type);
				$proxy->conn_time($conn_time);
				
				if ($speed_checker) {
					my $speed = $class->_check_speed($speed_checker, $config->speed_check->url, $proxy)
						or do {
							$proxy->delete();
							next;
						};
					
					$proxy->speed($speed);
					$proxy->speed_check_date(DateTime->now(time_zone => 'local'));
				}
				
				$proxy->checked(1);
				$proxy->worked(1);
				$proxy->check_date(DateTime->now(time_zone => 'local'));
				$proxy->in_progress(0);
				$proxy->fails(0);
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
				LWP::UserAgent->new(agent => 'Mozilla 5.0', timeout => 10) :
				undef;
			
			while (1) {
				if ($delay) {
					Coro::Timer::sleep $delay;
					next;
				}
				
				unless (@queue) {
					unless (@queue = $class->_get_queue({checked => 1}, {order_by => 'check_date'})) {
						$delay = CORO_DELAY;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
					
					my $sec_after_last_check = DateTime->now(time_zone => 'local')->
							subtract_datetime_absolute($queue[0]->check_date)->seconds;
					
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
					$proxy->type($type);
					$proxy->conn_time($conn_time);
					
					if ($speed_checker) {
						if (my $speed = $class->_check_speed($speed_checker, $config->speed_check->url, $proxy)) {
							$proxy->speed($speed);
						}
						else {
							$fail = 1;
							$proxy->speed(0);
						}
						
						$proxy->speed_check_date(DateTime->now(time_zone => 'local'));
					}
				}
				else {
					$fail = 1;
				}
				
				if ($fail) {
					$proxy->fails($proxy->fails+1);
					if ($proxy->fails > $config->recheck->fails_before_delete) {
						$proxy->delete();
						next;
					}
				}
				else {
					$proxy->fails(0);
				}
				
				$proxy->check_date(DateTime->now(time_zone => 'local'));
				$proxy->in_progress(0);
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
			my $speed_checker = LWP::UserAgent->new(agent => 'Mozilla 5.0', timeout => 10);
			
			while (1) {
				if ($delay) {
					Coro::Timer::sleep $delay;
					next;
				}
				
				unless (@queue) {
					unless (@queue = $class->_get_queue({checked => 1}, {order_by => 'speed_check_date'})) {
						$delay = CORO_DELAY;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
					
					my $sec_after_last_check = DateTime->now(time_zone => 'local')->
							subtract_datetime_absolute($queue[0]->speed_check_date)->seconds;
					
					if ($sec_after_last_check < $config->speed_checker->interval) {
						$delay = $config->speed_checker->interval - $sec_after_last_check;
						Coro::Timer::sleep $delay;
						$delay = 0;
						next;
					}
				}
				
				my $proxy = shift @queue;
				if (my $speed = $class->_check_speed($speed_checker, $config->speed_check->url, $proxy)) {
					$proxy->speed($speed);
				}
				else {
					$proxy->fails($proxy->fails+1);
					if ($proxy->fails > $config->recheck->fails_before_delete) {
						$proxy->delete();
						next;
					}
					$proxy->speed(0);
				}
				
				$proxy->speed_check_date(DateTime->now(time_zone => 'local'));
				$proxy->in_progress(0);
				$proxy->update();
			}
		}
	}
}

sub _check {
	my ($class, $checker, $proxy) = @_;
	
	my @check_mask;
	if ($proxy->type) {
		# first check for previous type of the proxy to speed up
		push @check_mask, $proxy->type;
		push @check_mask, (HTTP_PROXY|HTTPS_PROXY|SOCKS4_PROXY|SOCKS5_PROXY)&(~$proxy->type);
	}
	else {
		push @check_mask, HTTP_PROXY|HTTPS_PROXY|SOCKS4_PROXY|SOCKS5_PROXY;
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
	&HTTP_PROXY   => 'http',
	&HTTPS_PROXY  => 'connect'
	&SOCKS4_PROXY => 'socks4',
	&SOCKS5_PROXY => 'socks',
);

sub _check_speed {
	my ($class, $checker, $url, $proxy) = @_;
	
	$checker->proxy(['http', 'https'] => sprintf('%s://%s:%s', $uri_scheme{$proxy->type}, $proxy->host, $proxy->port));
	
	my @speed_variations;
	my $received_bytes = 0;
	my $curspeed;
	my $maxbytes = 1024*1024;
	my $start = Time::HiRes::time();
	
	my $resp = $checker->get($url, ':content_cb' => sub {
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
	});
	
	return if $resp->code > 299;
	return $curspeed;
}

1;

__END__

__DATA__
db = {
	driver: "mysql",
	driver_cfg: {
		"mysql_auto_reconnect": 1,
		"mysql_enable_utf8": 1
	},
	host: "localhost",
	schema: "proxyhunter"
	login: "root",
	password: "toor"
}

# first check
check = {
	workers: 30,
	speed_check: true # do immediate speed check
	                  # if true will performe speed check
	                  # even if speed_check.enabled is false
}

# recheck for alive proxies
recheck = {
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
	url: "http://mirror.yandex.ru/debian/ls-lR.gz" # should be > 1 mb
}


search = {
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