package App::ProxyHunter::Model::Schema::Pg;

use strict;
use Teng::Schema::Declare;
use DateTime::Format::Pg;
use App::ProxyHunter::Constants;
use App::ProxyHunter::Model::SchemaUtils qw'proxy_name_to_type proxy_type_to_name';

sub perl_datetime_to_sql {
	return unless defined $_[0];
	DateTime::Format::Pg->format_datetime($_[0]);
}

sub sql_datetime_to_perl {
	return unless defined $_[0];
	DateTime::Format::Pg->parse_datetime($_[0])->set_time_zone(TZ);
}

table {
	name 'proxy';
	pk 'id';
	columns qw(
		id
		host
		port
		checked
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
