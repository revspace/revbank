use v5.32;

# NOTE: While it is possible to install RevBank with `make install` after
# running this file, as is customary with Perl software, THIS IS NOT NECESSARY.
#
# RevBank also just runs from a cloned git repo: just run `./revbank`
#
# Makefile.PL was added because there are package builders that can use it.

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
