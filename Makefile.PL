use v5.10;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME          => 'RevBank',
    VERSION_FROM  => 'revbank',
    ABSTRACT_FROM => 'lib/RevBank.pod',
    EXE_FILES     => [ 'revbank' ],
    PREREQ_PM     => { },
    AUTHOR        => 'Juerd Waalboer <juerd@cpan.org>',
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/revspace/revbank.git',
                web  => 'https://github.com/revspace/revbank',
            },
            bugtracker => {
                web => 'https://github.com/revspace/revbank/issues'
            },
        },
    },
);
