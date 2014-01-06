package App::ProxyHunter::Model::SchemaUtils;

use Mo;
use Net::Proxy::Type;
extends 'Exporter';

our @EXPORT_OK = qw'proxy_name_to_type proxy_type_to_name';

my %PROXY_TYPE_MAP = %Net::Proxy::Type::NAME;
my %PROXY_NAME_MAP = reverse %PROXY_TYPE_MAP;

sub proxy_name_to_type {
	return $PROXY_NAME_MAP{$_[0]};
}

sub proxy_type_to_name {
	return $PROXY_TYPE_MAP{$_[0]};
}

1;
