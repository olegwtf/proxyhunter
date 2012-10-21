#!/usr/bin/perl

use strict;
use Coro::LWP;
use Coro::Timer;
use Coro;
use DBI;
use Net::Proxy::Type 0.06 ':types';
use LWP::UserAgent;
use LWP::Protocol::socks;
use LWP::Protocol::socks4;
use Time::HiRes;
use Config::File 'read_config_file';

my $cfg = read_config_file('config.cfg');
my %scheme = (HTTP_PROXY, 'http', SOCKS5_PROXY, 'socks', SOCKS4_PROXY, 'socks4', HTTPS_PROXY, 'http');

if($ARGV[0] eq '-d') {
	# demonizing
	if($cfg->{pid}{check} && -e $cfg->{pid}{check}) {
		open FH, $cfg->{pid}{check};
		chomp(my $pid = <FH>);
		close FH;
		
		if(kill 0, $pid) {
			die "Already running with pid $pid\n";
		}
	}
	
	require Proc::Daemon;
	Proc::Daemon->VERSION(0.05);
	
	Proc::Daemon->new(
		child_STDERR => $cfg->{log}{check} ? $cfg->{log}{check} : '/dev/null',
		pid_file => $cfg->{pid}{check},
		work_dir => '.',
	)->Init();
}

my $db = DBI->connect('DBI:mysql:dbname=' .$cfg->{db_name}. '; host=' .$cfg->{db_host}, $cfg->{db_user}, $cfg->{db_pass})
	or die $DBI::errstr;
my %sth = (
	selectcq => $db->prepare( # check
	#               0     1       2        3        4       5 
		'SELECT `id`, `host`, `port`, `fails`, `type`, `worked` FROM `proxylist`
		WHERE `in_progress`=0 AND TIMESTAMPDIFF(SECOND, `checkdate`, NOW()) >= ' . $cfg->{min_recheck_interval} . '
		ORDER BY `checked`, `checkdate` LIMIT ' . $cfg->{select_limit}
	),
	selectrq => $db->prepare( # recheck
		'SELECT `id`, `host`, `port`, `fails`, `type`, `worked` FROM `proxylist`
		WHERE `in_progress`=0 AND `checked`=1 AND TIMESTAMPDIFF(SECOND, `checkdate`, NOW()) >= ' . $cfg->{min_recheck_interval} . '
		ORDER BY `checkdate` LIMIT ' . $cfg->{select_limit}
	),
	#                                                                                                  generate placeholders
	setprgq => $db->prepare('UPDATE `proxylist` SET `in_progress`=1 WHERE `id` IN (' . join(',', map('?', 1..$cfg->{select_limit})) . ')'),
	updateq => $db->prepare(
		'UPDATE `proxylist` SET `checked`=1, `worked`=1, `checkdate`=NOW(), `in_progress`=0, `fails`=?, `type`=?, `conn_time`=?, `speed`=? WHERE `id`=?'
	),
	deleteq => $db->prepare('DELETE FROM `proxylist` WHERE `id`=?')
);

$SIG{INT} = $SIG{TERM} = sub {
	# unfortunaly END{} block doesn't work in this program, may be because of using Coro
	$db->do("UPDATE `proxylist` SET `in_progress`=0 WHERE `in_progress`<>0");
	$_->finish foreach values %sth;
	$db->disconnect;
	
	exit;
};

my @workers;
$db->do("UPDATE `proxylist` SET `in_progress`=0 WHERE `in_progress`<>0");

for (1 .. $cfg->{check_workers}+$cfg->{recheck_workers}) {
	push @workers, async {
		no strict 'refs';
		my $selectkey = shift;
	
		my $pt = Net::Proxy::Type->new(http_strict => 1, noauth => 1);
		my $ua = LWP::UserAgent->new(agent => 'Mozilla 5.0', timeout => 10);
		my ($list, $conn_time, $type, $row, @ids, $speed);
		
		while(1) {
			if(int( $sth{$selectkey}->execute() )) {
				# select result not empty
				$list = $sth{$selectkey}->fetchall_arrayref;
				
				# set in_progress to true for selected proxy list
				@ids = map $_->[0], @$list;
				# if id list smaller than placeholder list add some not existing id list
				push @ids, -1 for @ids+1..$cfg->{select_limit};
				$sth{setprgq}->execute(@ids);
				
				foreach $row (@$list) {
					($type, $conn_time) = $pt->get($row->[1], $row->[2], $row->[4] ne 'DEAD_PROXY' ? &{$row->[4]} : undef);
					
					if($type == DEAD_PROXY || $type == UNKNOWN_PROXY) {
						$row->[3]++;
						if(!$row->[5] || $row->[3] == $cfg->{fails_to_delete}) {
							# if checked first and failed or number of failes is more than value in config
							$sth{deleteq}->execute($row->[0]);
						}
						else {
							$sth{updateq}->execute($row->[3], 'DEAD_PROXY', $conn_time, -1, $row->[0]);
						}
					}
					else {
						# working proxy
						if ($cfg->{speed_check_url}) {
							$speed = get_speed($ua, "$scheme{$type}://$row->[1]:$row->[2]", $cfg->{speed_check_url});
						}
						else {
							$speed = 0;
						}
						
						$sth{updateq}->execute(0, $Net::Proxy::Type::NAME{$type}, $conn_time, $speed, $row->[0]);
					}
				}
			}
			else {
				Coro::Timer::sleep(5);
			}
		}
	} $_ <= $cfg->{check_workers} ? 'selectcq' : 'selectrq'; # first we start checkers and then recheckers
}

$_->join foreach @workers;

# do normal exit --> go to signal handler
kill 15, $$;


sub get_speed {
	my ($ua, $proxy, $url) = @_;
	$ua->proxy(http => $proxy);
	
	my @speed_variations;
	my $received_bytes = 0;
	my $curspeed;
	my $maxbytes = 1024*1024;
	my $start = Time::HiRes::time();
	
	my $resp = $ua->get($url, ':content_cb' => sub {
		$received_bytes += length($_[0]);
		$curspeed = $received_bytes / (Time::HiRes::time() - $start);
		die if $received_bytes > $maxbytes;
	
		if (@speed_variations == 10) {
			my $ok = 1;
			for my $s (@speed_variations) {
				if (abs($s - $curspeed) > 5 * 1024) {
					$ok = 0;
					last;
				}
			}
			
			die if $ok;
			shift @speed_variations;
		}
		
		push @speed_variations, $curspeed;
	});
	
	return $resp->code > 299 ? -1 : $curspeed;
}
