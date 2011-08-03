package Net::Proxy::Search::Plugins;

use strict;
use File::Basename;

our $QUERY = 'proxy list';

sub new
{
	my ($class) = @_;
	my $self = {};
	
	bless $self, $class;
}

sub list
{
	my ($self) = @_;
	my (@plugins, $dir, $dh);
	
	foreach my $libpath (@INC) {
		$dir = "$libpath/Net/Proxy/Search/Plugin";
		unless(-e $dir) {
			next;
		}
		
		unless(opendir($dh, $dir)) {
			next;
		}
		
		push @plugins, map { basename($_, '.pm') } grep {/\.pm$/} readdir($dh);
		
		closedir($dh);
	}
	
	return @plugins;
}

sub load
{
	my ($self, $name) = @_;
	
	if(defined $name) {
		eval "require $name"
			or die $@;
		$self->{$name} = undef;
		
		return;
	}
	
	foreach my $module ($self->list) {
		$name = "Net::Proxy::Search::Plugin::$module";
		eval "require $name"
			or die $@;
		$self->{$name} = undef;
	}
}

sub loaded
{
	my ($self) = @_;
	return keys %{$self};
}

sub init
{
	my $self = shift;
	# @_ contains query list
	
	foreach my $module ($self->loaded) {
		$self->{$module} = $module->new( shift || $QUERY );
	}
}

1;
