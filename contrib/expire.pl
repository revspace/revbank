#!/usr/bin/perl
use v5.32;
use warnings;
use autodie;
use POSIX qw(strftime);

my $delete = @ARGV && $ARGV[0] eq 'delete';

my @cutoff = localtime;
$cutoff[5] -= 5;  # year
my $cutoff = strftime '%Y-%m-%d %H:%M:%S', @cutoff;

if ($delete) {  # stap 2
    # Accounts die net op 0 zijn gezet, hebben een datumtijd van *nu* en lijken
    # dus niet expired. Maar de vorige stap heeft daarom dit bestandje
    # achtergelaten.

    my %expired;
    open my $exp, '<', '.revbank/.expire';
    while (defined($_ = readline $exp)) {
        chomp;
        $expired{$_}++;
    }
    close $exp;

    open my $new, '>', ".revbank/accounts.$$";
    open my $fh, '<', '.revbank/accounts';
    while (defined($_ = readline $fh)) {
        my ($user, $balance, $date) = split " ";
        print $new $_ unless $balance == 0 and ($date lt $cutoff or exists $expired{$user});
    }
    close $fh;
    close $new;
    rename ".revbank/accounts.$$", ".revbank/accounts";
    system 'git -C .revbank diff';
    system 'git -C .revbank commit -mexpired accounts';
} else {  # stap 1
    open my $exp, '>', '.revbank/.expire';
    open my $fh, '<', '.revbank/accounts';
    my $count = 0;
    while (defined($_ = readline $fh)) {
        my ($user, $balance, $date) = split " ";
        if ($date lt $cutoff and $balance > 0) {
            $count++;
            print $exp "$user\n";
            print STDOUT "donate $balance 'account expired'; $user;\n" 
        }
    }
    close $fh;
    close $exp;

    die "Momenteel niks te expiren!\n" if not $count;
    print "1. Copy/paste bovenstaande naar revbank.\n";
    print "2. Draai '$0 delete' om oude accounts die op 0.00 staan te verwijderen.\n"
}

