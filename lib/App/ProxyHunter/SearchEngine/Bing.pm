package App::ProxyHunter::SearchEngine::Bing;

use Mo 'build';
use List::MoreUtils 'uniq';
extends 'App::ProxyHunter::SearchEngine';

sub BUILD {
	my $self = shift;
	
	$self->{links} = [];
	$self->{prev_links} = [];
}

sub next {
	my $self = shift;
	
	unless (@{$self->{links}}) {
		$self->{offset} += defined($self->{offset}) ? 10 : 1;
		
		my $page = $self->ua->get('http://www.bing.com/search?q='.$self->query.'&first='.$self->{offset})->decoded_content;
		@{$self->{links}} = $page =~ /<h3>\s*<a\s+href=["']([^'"]+)/gi
			or return;
		
		if(uniq(@{$self->{links}}, @{$self->{prev_links}}) == @{$self->{prev_links}}) {
			# if there is no page at given offset bing will display last available
			# so, if links from previous result are same to links from the current
			# it seems that there are no more search results available
			return;
		}
		
		@{$self->{prev_links}} = @{$self->{links}};
	}
	
	return $self->_get_proxylist(shift @{$self->{links}});
}

1;
