package App::ProxyHunter::Model::Schema;

use strict;

sub get_create_query {
	my $class = shift;
	
	my $q;
	no strict 'refs';
	my $fh = \*{$class.'::DATA'};
	
	while (my $str = <$fh>) {
		$q .= $str;
		if ($str =~ /;\s*$/) {
			last;
		}
	}
	
	return $q;
}

1;
