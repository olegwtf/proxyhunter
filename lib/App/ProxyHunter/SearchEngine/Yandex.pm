package App::ProxyHunter::SearchEngine::Yandex;

use Mo 'build';
extends 'App::ProxyHunter::SearchEngine';

sub BUILD {
	my $self = shift;
	$self->{links} = [];
}

sub next {
	my $self = shift;
	
	unless (@{$self->{links}}) {
		$self->{offset} += defined($self->{offset}) ? 1 : 0;
		
		my $page = $self->ua->get('http://yandex.ru/yandsearch?text='.$self->query.'&p='.$self->{offset})->decoded_content;
		@{$self->{links}} = $page =~ /<h2.{1,200}?<a\b[^>]+?href\s*=\s*["]([^"]+)/gis
			or return;
		# if there is no page at given offset yandex will display 404 error
	}
	
	return $self->_get_proxylist(shift @{$self->{links}});
}

1;
