package App::ProxyHunter::Config;

use Mo qw'is build required';
use Parse::JCONF;
use Carp;

has path                => (is => 'ro', required => 1);
has db                  => (is => 'ro');
has checker             => (is => 'ro');
has rechecker           => (is => 'ro');
has speed_checker       => (is => 'ro');
has searcher            => (is => 'ro');

sub BUILD {
	my $self = shift;
	
	open my $fh, $self->path
		or croak sprintf("Can't open `%s': %s", $self->path, $!);
	
	my $jcfg = do {
		local $/;
		my $raw_cfg = <$fh>;
		Parse::JCONF->new(autodie => 1)->parse($raw_cfg);
	};
	
	close $fh;
	
	$self->{db}            = ProxyHunter::Config::DB->new( %{$jcfg->{db}} );
	$self->{checker}       = ProxyHunter::Config::Checker->new( %{$jcfg->{check}} );
	$self->{rechecker}     = ProxyHunter::Config::Rechecker->new( %{$jcfg->{recheck}} );
	$self->{speed_checker} = ProxyHunter::Config::SpeedChecker->new( %{$jcfg->{speed_check}} );
	$self->{searcher}      = ProxyHunter::Config::Searcher->new( %{$jcfg->{search}} );
}

package ProxyHunter::Config::DB;

use Mo 'default';

has driver     => (default => 'SQLite');
has driver_cfg => (default => {});
has host       => (default => 'localhost');
has login      => (default => 'root');
has password   => (default => '');
has schema     => (default => 'proxymonitor');

package ProxyHunter::Config::Checker;

use Mo 'default';

has speed_check  => (default => 1);
has workers      => (default => 30);

package ProxyHunter::Config::Rechecker;

use Mo 'default';

has speed_check         => (default => 0);
has workers             => (default => 10);
has interval            => (default => 300);
has fails_before_delete => (default => 3);

package ProxyHunter::Config::SpeedChecker;

use Mo 'default';

has enabled  => (default => 1);
has workers  => (default => 10);
has interval => (default => 1800);
has url      => (default => "http://mirror.yandex.ru/debian/ls-lR.gz");

package ProxyHunter::Config::Searcher;

use Mo 'default';

has querylist => (default => ['free proxy']);
has engines   => ['Google', 'Bing', 'Yandex'];

1;
