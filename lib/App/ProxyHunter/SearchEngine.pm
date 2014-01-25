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

__END__

=pod

=head1 NAME

App::ProxyHunter::SearchEngine - base class for proxyhunter's search engine

=head1 SYNOPSIS

	package App::ProxyHunter::SearchEngine::MyEngine;
	
	use Mo;
	extends 'App::ProxyHunter::SearchEngine';
	
	sub next {
		my $self = shift;
		...
		return unless $has_more;
		return $self->_get_proxylist($url);
	}

=head1 SUBCLASSING

You should inherit this class to implement specific search engine. This subclass may be adapter for some search engine like
yahoo.com or for some specific site with proxy list.

=head2 METHODS

=head3 $self->next()

This method should be implemented in subclass and return reference to array with portion of proxies in C<host:port> format
or undef if there is no more proxies.

=head2 $self->_get_proxylist($url)

This method implemented in base class and may be used in subclass to extract proxy list from specified $url. It returns
reference to array with found proxies. It uses some simple regular expression for search and may not find any proxy for
some tricky web sites.

=head2 ATTRIBUTES

=head3 $self->ua

This attribute contains LWP::UserAgent instance which may be used for http requests

=head3 $self->query

This attribute contains urlencoded query which should be used in subclass to search for proxy list. You can ignore it if this is
adapter for some specific site with proxy list where you don't need query.

=cut
