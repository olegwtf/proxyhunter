package Net::Proxy::Search::Plugin::Yandex;

use strict;
use base qw(Net::Proxy::Search::Plugin);

my $SELF_REGEXP = qr/<h2.{1,200}?<a\b[^>]+?href\s*=\s*["]([^"]+)/is;

sub next
{
	my $self = shift;
	my $page;
	
	unless(@{$self->{links}}) {
		$self->{offset} += defined($self->{offset}) ? 1 : 0;
		
		$page = $self->{ua}->get('http://yandex.ru/yandsearch?text='.$self->{query}.'&p='.$self->{offset})->content;
		@{$self->{links}} = $page =~ /$SELF_REGEXP/g
			or return $self->_empty;
			
		# if there is no page at givven offset yandex will display 404 error
	}
	
	$page = $self->{ua}->get( shift @{$self->{links}} )->content;
	my @result = $page =~ /${ \($self->SUPER::REGEXP) }/g;
}

1;
