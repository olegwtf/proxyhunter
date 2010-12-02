#!/usr/bin/perl

use strict;
use lib('lib');
use Socket;
use DBI;
use Net::Proxy::Search::Plugins;
use Config::File 'read_config_file';

my $cfg = read_config_file('config.cfg');
my $db = DBI->connect('DBI:mysql:dbname=' .$cfg->{db_name}. '; host=' .$cfg->{db_host}, $cfg->{db_user}, $cfg->{db_pass})
	or die $DBI::errstr;
my $sth = $db->prepare("INSERT IGNORE INTO `proxylist` SET `host`=?, `port`=?");

my $plugins = Net::Proxy::Search::Plugins->new();
$plugins->load();
$plugins->init();

my %plugins = %{$plugins};
my $ip_regexp = qr/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
my ($proxy, @proxylist);
my ($host, $port, @hostent);

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

$sth->finish;
$db->disconnect;
