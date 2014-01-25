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

__END__

=pod

=head1 NAME

App::ProxyHunter::Model::Schema - base class for proxyhunter's schema

=head1 SYNOPSIS

	package App::ProxyHunter::Model::Schema::mydb;
	
	use Mo;
	extends 'App::ProxyHunter::Model::Schema';
	
	table {
		...
	}

=head1 SUBCLASSING

You should inherit this class to implement adapter for specific database. In this subclass you need to declare
database schema using C<Teng::Schema::Declare>. This package should contain C<__DATA__> section with create statement
for database. See available implementations.

=cut
