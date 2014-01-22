package App::ProxyHunter::SearchEngine;

use Mo qw'is default required coerce';
use Carp;
use URI::Escape;
use LWP::UserAgent;

$URI::Escape::escapes{' '} = '+';

has ua    => (default => LWP::UserAgent->new(timeout => 10, agent => 'Mozilla/5.0', max_size => 1024**2, parse_head => 0));
has query => (is => 'ro', required => 1, coerce => sub { uri_escape_utf8($_[0]) });

sub next {
	confess 'not implemented';
}

sub _get_proxylist {
	my ($self, $url) = @_;
	
	my $page = $self->ua->get($url)->decoded_content;
	$page =~ s/<[^>]+>/ /g;
	
	my @res;
	while ($page =~ /(?:(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|\s[a-z0-9.-]{3,100}?\.[a-z]{2,10}))(?:\s*:\s*|\s+)(\d{2,5})/gi) {
		push @res, "$1:$2";
	}
	
	return \@res;
}

1;
