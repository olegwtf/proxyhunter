#!/usr/bin/perl

use strict;
use lib('lib');
use Socket;
use DBI;
use List::Util 'shuffle';
use Net::Proxy::Search::Plugins;
use Config::File 'read_config_file';

my $cfg = read_config_file('config.cfg');

if($ARGV[0] eq '-d') {
	# demonizing
	if($cfg->{pid}{search} && -e $cfg->{pid}{search}) {
		open FH, $cfg->{pid}{search};
		chomp(my $pid = <FH>);
		close FH;
		
		if(kill 0, $pid) {
			die "Already running with pid $pid\n";
		}
	}
	
	require Proc::Daemon;
	if($Proc::Daemon::VERSION < 0.05) {
		die "Proc::Daemon version 0.05 required--this is only version $Proc::Daemon::VERSION";
	}
	
	Proc::Daemon->new(
		child_STDERR => $cfg->{log}{search} ? $cfg->{log}{search} : '/dev/null',
		pid_file => $cfg->{pid}{search},
		work_dir => '.',
	)->Init();
}

my $db = DBI->connect('DBI:mysql:dbname=' .$cfg->{db_name}. '; host=' .$cfg->{db_host}, $cfg->{db_user}, $cfg->{db_pass})
	or die $DBI::errstr;
my $sth = $db->prepare("INSERT IGNORE INTO `proxylist` SET `host`=?, `port`=?");

$SIG{INT} = $SIG{TERM} = sub { exit };

my $plugins = Net::Proxy::Search::Plugins->new();
$plugins->load();

my $ip_regexp = qr/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
my @queries = values %{$cfg->{search_query}};
my ($proxy, @proxylist);
my ($host, $port, @hostent);

while(1) {
	@queries = shuffle @queries;
	$plugins->init(@queries);
	my %plugins = %{$plugins};
	
	while(%plugins) {
		foreach my $module (keys %plugins) {
			@proxylist = $plugins{$module}->next;
			
			foreach $proxy (@proxylist) {
				($host, $port) = split /:/, $proxy;
				
				if($host !~ $ip_regexp) {
					# hostname to ip for more efficient work with database
					@hostent = gethostbyname($host)
						or next;
					$host = join('.', unpack('C4', $hostent[4]));
				}
				
				$sth->execute($host, $port);
			}
			
			delete $plugins{$module}
				if $plugins{$module}->empty;
		}
	}
}

END {
	if($db) {
		$sth->finish;
		$db->disconnect;
	}
}
