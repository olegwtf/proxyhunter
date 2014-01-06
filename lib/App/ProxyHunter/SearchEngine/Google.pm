package App::ProxyHunter::SearchEngine::Google;

use Mo;
use List::MoreUtils 'uniq';
use URI::Escape;
extends 'App::ProxyHunter::SearchEngine';

sub next {
	my $self = shift;
	
	unless (@{$self->_links}) {
		$self->{offset} += defined($self->{offset}) ? 10 : 0;
		
		my $page = $self->ua->get('http://www.google.com/search?q='.$self->query.'&start='.$self->{offset})->decoded_content;
		@{$self->_links} = map { uri_unescape($_) } $page =~ /<h3\s+?class="r">\s*<a\s+href="\/url\?q=([^"]+?)&amp;/gi
			or return;
		
		if(uniq(@{$self->_links}, @{$self->_prev_links}) == @{$self->_prev_links}) {
			# if there is no page at givven offset google will display last available
			# so, if links from previous result are same to links from the current
			# it seems that there are no more search results available
			return;
		}
		
		@{$self->_prev_links} = @{$self->_links};
	}
	
	return $self->_get_proxylist(shift @{$self->_links});
}

1;
