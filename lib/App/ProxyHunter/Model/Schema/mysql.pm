package App::ProxyHunter::Model::Schema::mysql;

use strict;
use Teng::Schema::Declare;
use DateTime::Format::MySQL;
use Net::Proxy::Type;

my %PROXY_TYPE_MAP = %Net::Proxy::Type::NAME;
my %PROXY_NAME_MAP = reverse %PROXY_TYPE_MAP;

sub proxy_name_to_type {
	return $PROXY_NAME_MAP{$_[0]};
}

sub proxy_type_to_name {
	return $PROXY_TYPE_MAP{$_[0]};
}

sub perl_datetime_to_sql {
	return unless defined $_[0];
	DateTime::Format::MySQL->format_datetime($_[0]);
}

sub sql_datetime_to_perl {
	return unless defined $_[0] && $_[0] ne '0000-00-00 00:00:00';
	DateTime::Format::MySQL->parse_datetime($_[0])->set_time_zone('local');
}

table {
	name 'proxy';
	pk 'id';
	columns qw(
		id
		host
		port
		checked
		worked
		checkdate
		speed_checkdate
		fails
		type
		in_progress
		conn_time
		speed
	);
	
	inflate type => \&proxy_name_to_type;
	deflate type => \&proxy_type_to_name;
	
	for (qw/checkdate speed_checkdate/) {
		inflate $_ => \&sql_datetime_to_perl;
		deflate $_ => \&perl_datetime_to_sql;
	}
};

1;
