package App::ProxyHunter::Model::Schema::Pg;

use Mo;
use Teng::Schema::Declare;
use DateTime::Format::Pg;
use App::ProxyHunter::Constants;
use App::ProxyHunter::Model::SchemaUtils qw'proxy_name_to_type proxy_type_to_name';
extends 'App::ProxyHunter::Model::Schema';

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
		success_total
		fails_total
		insertdate
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
	
	for (qw/insertdate checkdate speed_checkdate/) {
		inflate $_ => \&sql_datetime_to_perl;
		deflate $_ => \&perl_datetime_to_sql;
	}
};

1;

__DATA__
CREATE TYPE proxy_type AS ENUM ('HTTPS_PROXY','HTTP_PROXY','CONNECT_PROXY','SOCKS4_PROXY','SOCKS5_PROXY','DEAD_PROXY');
CREATE TABLE proxy
(
  id serial NOT NULL,
  host character varying(15) NOT NULL,
  port integer NOT NULL,
  checked boolean NOT NULL DEFAULT false,
  success_total integer NOT NULL DEFAULT 0,
  fails_total integer NOT NULL DEFAULT 0,
  insertdate timestamp without time zone NOT NULL,
  checkdate timestamp without time zone NOT NULL DEFAULT '1980-01-01 00:00:00'::timestamp without time zone,
  speed_checkdate timestamp without time zone NOT NULL DEFAULT '1980-01-01 00:00:00'::timestamp without time zone,
  fails smallint NOT NULL DEFAULT 0,
  type proxy_type NOT NULL DEFAULT 'DEAD_PROXY'::proxy_type,
  in_progress boolean NOT NULL DEFAULT false,
  conn_time integer DEFAULT NULL,
  speed integer NOT NULL DEFAULT 0,
  CONSTRAINT proxy_pk PRIMARY KEY (id),
  CONSTRAINT proxy_uniq UNIQUE (host, port)
);
CREATE INDEX sort_idx
  ON proxy
  USING btree
  (checked, checkdate);
CREATE INDEX type_idx
  ON proxy
  USING btree
  (type);
