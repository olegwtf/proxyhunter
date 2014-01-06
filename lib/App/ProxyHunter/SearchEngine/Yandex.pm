package App::ProxyHunter::SearchEngine::Yandex;

use Mo;
extends 'App::ProxyHunter::SearchEngine';

sub next {
	my $self = shift;
	
	unless (@{$self->_links}) {
		$self->{offset} += defined($self->{offset}) ? 1 : 0;
		
		my $page = $self->ua->get('http://yandex.ru/yandsearch?text='.$self->query.'&p='.$self->{offset})->decoded_content;
		@{$self->_links} = $page =~ /<h2.{1,200}?<a\b[^>]+?href\s*=\s*["]([^"]+)/gis
			or return;
		# if there is no page at givven offset yandex will display 404 error
	}
	
	return $self->_get_proxylist(shift @{$self->_links});
}

1;
