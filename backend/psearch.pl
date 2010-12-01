use strict;
use lib('lib');
use Net::Proxy::Search::Plugin::Yandex;

my $s = Net::Proxy::Search::Plugin::Yandex->new('proxy list');

until($s->empty) {
	my @res = $s->next;
	if(@res) {
		require Data::Dumper;
		print Data::Dumper::Dumper(@res);
		next;
	}
	
	print "not found\n";
}
