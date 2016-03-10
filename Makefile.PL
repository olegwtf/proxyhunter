use 5.006000;
use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'proxyhunter',
    LICENSE           => 'perl',
    VERSION_FROM      => 'lib/App/ProxyHunter.pm',
    PREREQ_PM         => {
        Coro::                   => 2.5,
        Coro::PatchSet::         => 0.13,
        LWP::UserAgent::         => 6.02,
        LWP::Protocol::https::   => 6.02,
        LWP::Protocol::connect:: => 6.09,
        LWP::Protocol::socks::   => 1.7,
        Net::Proxy::Type::       => 0.09,
        Getopt::Long::           => 2.39,
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
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            bugtracker => {
                web => 'https://github.com/olegwtf/proxyhunter/issues',
            },
            repository => {
                type => 'git',
                url => 'https://github.com/olegwtf/proxyhunter.git',
                web => 'https://github.com/olegwtf/proxyhunter',
            },
        },
    },
    ($] >= 5.005 ?
    (ABSTRACT_FROM  => 'bin/proxyhunter',
    AUTHOR         => 'Oleg G <oleg@cpan.org>') : ()),
);
