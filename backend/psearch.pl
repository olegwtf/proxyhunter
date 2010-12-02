use strict;
use lib('lib');
use Net::Proxy::Search::Plugins;
use Data::Dumper;

my $plugins = Net::Proxy::Search::Plugins->new();
$plugins->load();
$plugins->init();

my %plugins = %{$plugins};
my @proxylist;

while(%plugins) {
	foreach my $module (keys %plugins) {
		@proxylist = $plugins{$module}->next;
		delete $plugins{$module}
			if $plugins{$module}->empty;
	}
}
