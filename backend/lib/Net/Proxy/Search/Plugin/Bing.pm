package Net::Proxy::Search::Plugin::Bing;

use strict;
use base qw(Net::Proxy::Search::Plugin);
use List::MoreUtils qw (uniq);

my $SELF_REGEXP = qr/<h3>\s*<a\s+href=["']([^'"]+)/i;

sub next
{
	my $self = shift;
	my $page;
	
	unless(@{$self->{links}}) {
		$self->{offset} += $self->{offset} ? 10 : 1;
		
		$page = $self->{ua}->get('http://www.bing.com/search?q='.$self->{query}.'&first='.$self->{offset})->content;
		@{$self->{links}} = $page =~ /$SELF_REGEXP/g
			or return $self->_empty;
			
		if(uniq(@{$self->{links}}, @{$self->{tmp_links}}) == @{$self->{tmp_links}}) {
			# if there is no page at givven offset bing will display last available
			# so, if links from previous result are same to links from the current
			# it seems that there are no more search results available
			return $self->_empty;
		}
		
		@{$self->{tmp_links}} = @{$self->{links}};
	}
	
	$page = $self->{ua}->get( shift @{$self->{links}} )->content;
	my @result = $page =~ /${ \($self->SUPER::REGEXP) }/g;
}

1;
