package App::ProxyHunter::SearchEngine::Google;

use Mo 'build';
use List::MoreUtils 'uniq';
use URI::Escape;
extends 'App::ProxyHunter::SearchEngine';

sub BUILD {
	my $self = shift;
	
	$self->{links} = [];
	$self->{prev_links} = [];
}

sub next {
	my $self = shift;
	
	unless (@{$self->{links}}) {
		$self->{offset} += defined($self->{offset}) ? 10 : 0;
		
		my $page = $self->ua->get('http://www.google.com/search?q='.$self->query.'&start='.$self->{offset})->decoded_content;
		@{$self->{links}} = map { uri_unescape($_) } $page =~ /<h3\s+?class="r">\s*<a\s+href="\/url\?q=([^"]+?)&amp;/gi
			or return;
		
		if(uniq(@{$self->{links}}, @{$self->{prev_links}}) == @{$self->{prev_links}}) {
			# if there is no page at given offset google will display last available
			# so, if links from previous result are same to links from the current
			# it seems that there are no more search results available
			return;
		}
		
		@{$self->{prev_links}} = @{$self->{links}};
	}
	
	return $self->_get_proxylist(shift @{$self->{links}});
}

1;
