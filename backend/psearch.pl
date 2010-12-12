#!/usr/bin/perl

use strict;
use lib('lib');
use Socket;
use DBI;
use List::Util 'shuffle';
use Net::Proxy::Search::Plugins;
use Config::File 'read_config_file';

my $cfg = read_config_file('config.cfg');
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
	$sth->finish;
	$db->disconnect;
}
