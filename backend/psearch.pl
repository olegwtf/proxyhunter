use strict;
use lib('lib');
use Net::Proxy::Search::Plugin::Bing;

my $s = Net::Proxy::Search::Plugin::Bing->new('proxy list');

until($s->empty) {
	my @res = $s->next;
	if(@res) {
		require Data::Dumper;
		print Data::Dumper::Dumper(@res);
		next;
	}
	
	print "not found\n";
}
