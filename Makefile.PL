use 5.006000;
use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME              => 'proxyhunter',
	LICENSE           => 'perl',
	VERSION_FROM      => 'lib/App/ProxyHunter.pm',
	PREREQ_PM         => { 
		Coro::                   => 2.5,
		Coro::PatchSet::         => 0.07,
		LWP::UserAgent::         => 6.02,
		LWP::Protocol::https::   => 6.02,
		LWP::Protocol::connect:: => 6.09,
		LWP::Protocol::socks::   => 1.6,
		Net::Proxy::Type::       => 0.08,
		Time::HiRes::            => 0,
		DateTime::               => 0.50,
		List::Util::             => 1.3,
		URI::                    => 1.36,
		Mo::                     => 0.10,
		Parse::JCONF::           => 0.02,
		Teng::                   => 0.19,
		List::MoreUtils::        => 0.09,
	},
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => 6.52,
	},
	EXE_FILES         => [ 'bin/proxyhunter' ],
	META_MERGE        => {
		resources => {repository => 'https://github.com/olegwtf/proxyhunter'},
	},
	($] >= 5.005 ?
	(ABSTRACT_FROM  => 'bin/proxyhunter',
	AUTHOR         => 'Oleg G <oleg@cpan.org>') : ()),
);
