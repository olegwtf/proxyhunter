package App::ProxyHunter::Config;

use Mo qw'is build required';
use Parse::JCONF;
use Carp;

has path          => (is => 'ro', required => 1);
has db            => (is => 'ro');
has checker       => (is => 'ro');
has rechecker     => (is => 'ro');
has speed_checker => (is => 'ro');
has searcher      => (is => 'ro');

sub BUILD {
	my $self = shift;
	
	my $jcfg;
	eval {
		$jcfg = Parse::JCONF->new(autodie => 1)->parse_file($self->path);
	};
	if ($@) {
		if ($@->isa('Parse::JCONF::Error::Parser')) {
			die $self->path, ': ', $@;
		}
		die $@;
	}
	
	$self->{db}            = App::ProxyHunter::Config::DB->new( %{$jcfg->{db}} );
	$self->{checker}       = App::ProxyHunter::Config::Checker->new( %{$jcfg->{check}} );
	$self->{rechecker}     = App::ProxyHunter::Config::Rechecker->new( %{$jcfg->{recheck}} );
	$self->{speed_checker} = App::ProxyHunter::Config::SpeedChecker->new( %{$jcfg->{speed_check}} );
	$self->{searcher}      = App::ProxyHunter::Config::Searcher->new( %{$jcfg->{search}} );
}

package App::ProxyHunter::Config::DB;

use Mo 'default';

has driver     => (default => 'SQLite');
has driver_cfg => (default => {});
has host       => (default => 'localhost');
has login      => (default => '');
has password   => (default => '');
has name       => (default => 'proxyhunter');

package App::ProxyHunter::Config::Checker;

use Mo 'default';

has enabled      => (default => 1);
has speed_check  => (default => 1);
has workers      => (default => 30);

package App::ProxyHunter::Config::Rechecker;

use Mo 'default';

has enabled             => (default => 1);
has speed_check         => (default => 0);
has workers             => (default => 10);
has interval            => (default => 300);
has fails_before_delete => (default => 3);

package App::ProxyHunter::Config::SpeedChecker;

use Mo 'default';

has enabled   => (default => 1);
has workers   => (default => 10);
has interval  => (default => 1800);
has http_url  => (default => "http://mirror.yandex.ru/debian/ls-lR.gz");
has https_url => (default => "https://mail.ru/");

package App::ProxyHunter::Config::Searcher;

use Mo 'default';

has enabled   => (default => 1);
has querylist => (default => ['free proxy list']);
has engines   => ['Google', 'Bing', 'Yandex'];

1;
