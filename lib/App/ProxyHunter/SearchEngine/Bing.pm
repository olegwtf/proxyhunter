package App::ProxyHunter::SearchEngine::Bing;

use Mo;
use List::MoreUtils 'uniq';
extends 'App::ProxyHunter::SearchEngine';

sub next {
	my $self = shift;
	
	unless (@{$self->_links}) {
		$self->{offset} += defined($self->{offset}) ? 10 : 1;
		
		my $page = $self->ua->get('http://www.bing.com/search?q='.$self->query.'&first='.$self->{offset})->decoded_content;
		@{$self->_links} = $page =~ /<h3>\s*<a\s+href=["']([^'"]+)/gi
			or return;
		
		if(uniq(@{$self->_links}, @{$self->_prev_links}) == @{$self->_prev_links}) {
			# if there is no page at givven offset bing will display last available
			# so, if links from previous result are same to links from the current
			# it seems that there are no more search results available
			return;
		}
		
		@{$self->_prev_links} = @{$self->_links};
	}
	
	return $self->_get_proxylist(shift @{$self->_links});
}

1;
