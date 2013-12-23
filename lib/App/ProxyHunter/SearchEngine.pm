package App::ProxyHunter::SearchEngine;

use Mo 'is default required';
use Carp;
use URI::Escape;
use LWP::UserAgent;

$URI::Escape::escapes{' '} = '+';

has ua    => (default => LWP::UserAgent->new(timeout => 10, agent => 'Mozilla/5.0'));
has query => (is => 'ro', required => 1);

sub next {
	confess 'not implemented';
}

sub _get_proxylist {
	my ($self, $url) = @_;
	
	my $page = $self->ua->get($url)->decoded_content;
	my @res = $page =~ /((?:\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|[a-z0-9.-]+?\.[a-z]{2,10}):\d{2,5})/gi;
	return \@res;
}

1;
