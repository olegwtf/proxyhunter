package App::ProxyHunter::Constants;

use DateTime::TimeZone;

use constant {
	TZ => DateTime::TimeZone->new(name => 'local')
};

sub import {
	my $caller = caller;
	
	while (my ($name, $symbol) = each %{__PACKAGE__ . '::'}) {
		if (ref $symbol) {
			# only constants
			${$caller . '::'}{$name} = $symbol;
		}
	}
}

1;
