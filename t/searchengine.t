use strict;
use Test::More;

unless ($ENV{PROXYHUNTER_LIVE_TESTS}) {
	plan skip_all => 'Environment variable PROXYHUNTER_LIVE_TESTS should has true value';
}

use_ok('App::ProxyHunter::SearchEngine::Google');
use_ok('App::ProxyHunter::SearchEngine::Bing');
use_ok('App::ProxyHunter::SearchEngine::Yandex');

use constant QUERY => 'proxy list';

my $google = App::ProxyHunter::SearchEngine::Google->new(query => QUERY);
isa_ok($google, 'App::ProxyHunter::SearchEngine::Google');
ok($google->next, 'google has smth');
ok(@{$google->{links}} > 0, 'google: found links');

my $bing = App::ProxyHunter::SearchEngine::Bing->new(query => QUERY);
isa_ok($bing, 'App::ProxyHunter::SearchEngine::Bing');
ok($bing->next, 'bing has smth');
ok(@{$bing->{links}} > 0, 'bing: found links');

my $yandex = App::ProxyHunter::SearchEngine::Yandex->new(query => QUERY);
isa_ok($yandex, 'App::ProxyHunter::SearchEngine::Yandex');
ok($yandex->next, 'yandex has smth');
ok(@{$yandex->{links}} > 0, 'yandex: found links');

done_testing;
