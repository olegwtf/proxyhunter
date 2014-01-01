package App::ProxyHunter::Model::Schema::mysql;

use Mo;
use Teng::Schema::Declare;
use DateTime::Format::MySQL;
use App::ProxyHunter::Constants;
use App::ProxyHunter::Model::SchemaUtils qw'proxy_name_to_type proxy_type_to_name';
extends 'App::ProxyHunter::Model::Schema';

sub perl_datetime_to_sql {
	return unless defined $_[0];
	DateTime::Format::MySQL->format_datetime($_[0]);
}

sub sql_datetime_to_perl {
	return unless defined $_[0] && $_[0] ne '0000-00-00 00:00:00';
	DateTime::Format::MySQL->parse_datetime($_[0])->set_time_zone(TZ);
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

__DATA__
CREATE TABLE `proxy` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host` varchar(15) NOT NULL,
  `port` smallint(5) unsigned NOT NULL,
  `checked` tinyint(1) NOT NULL DEFAULT '0',
  `checkdate` datetime NOT NULL DEFAULT '1980-01-01 00:00:00',
  `speed_checkdate` datetime NOT NULL DEFAULT '1980-01-01 00:00:00',
  `fails` tinyint(1) NOT NULL DEFAULT '0',
  `type` enum('HTTPS_PROXY','HTTP_PROXY','CONNECT_PROXY','SOCKS4_PROXY','SOCKS5_PROXY','DEAD_PROXY') NOT NULL DEFAULT 'DEAD_PROXY',
  `in_progress` tinyint(1) NOT NULL DEFAULT '0',
  `conn_time` smallint(5) unsigned DEFAULT NULL,
  `speed` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `proxy` (`host`,`port`),
  KEY `sort` (`checked`,`checkdate`),
  KEY `type` (`type`)
);
