package RevBank::Users;
use strict;
use RevBank::Global;
use RevBank::Plugins;

my $filename = "revbank.accounts";

sub _read {
    my @users;
    open my $fh, $filename or die $!;
    /\S/ and push @users, [split " "] while readline $fh;
    close $fh;
    return { map { lc($_->[0]) => $_ } @users };
}

sub names {
    return map $_->[0], values %{ _read() };
}

sub balance {
    my ($name) = @_;
    return _read()->{ lc $name }->[1];
}

sub create {
    my ($username) = @_;
    open my $fh, '>>', $filename or die $!;
    my $now = now();
    print {$fh} "$username 0.00 $now\n" or die $!;
    close $fh or die $!;
    RevBank::Plugins::call_hooks("user_created", $username);
}

sub update {
    my ($username, $delta, $transaction_id) = @_;
    open my $in,  'revbank.accounts' or die $!;
    open my $out, ">.revbank.$$" or die $!;
    my $old;
    my $new;
    while (defined (my $line = readline $in)) {
        my @a = split " ", $line;
        if (lc $a[0] eq lc $username) {
            $old = $a[1];
            $new = $old + $delta;
            printf {$out} "%-16s %+9.2f %s",
                $username, $new, now() or die $!;
            print {$out} "\n" or die $!;
        } else {
            print {$out} $line or die $!;
        }
    }
    close $out or die $!;
    close $in;
    rename ".revbank.$$", "revbank.accounts" or die $!;

    RevBank::Plugins::call_hooks(
        "user_balance", $username, $old, $delta, $new, $transaction_id
    );
}

sub parse_user {
    my ($username) = @_;
    my $users = _read();
    return undef if not exists $users->{ lc $username };
    return $users->{ lc $username }->[0];
}

1;


