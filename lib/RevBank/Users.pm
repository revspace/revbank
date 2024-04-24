package RevBank::Users;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since v5.36

use RevBank::Global;
use RevBank::Plugins;
use Carp ();
use List::Util ();

my $filename = "revbank.accounts";

sub _read() {
    my @users;
    for my $line (slurp $filename) {
        $line =~ /\S/ or next;
        # Not using RevBank::Prompt::split_input to keep parsing by external
        # scripts simple, since so many such scripts exist.

        my @split = split " ", $line;

        if ($split[1] =~ /^!/) {
            # Special case: use rest of the line (see POD).
            @split = split " ", $line, 2;
        }

        push @users, \@split;
    }

    my %users;
    for (@users) {
        my $name = lc $_->[0];

        exists $users{$name} and die "$filename: duplicate entry '$name'\n";
        $users{$name} = $_;

        if ($name =~ s/^\*//) {
            # user-accessible special account: support without * prefix
            exists $users{$name} and die "$filename: duplicate entry '$name'\n";
            $users{$name} = $_;
        }
    }
    return \%users;
}

sub names() {
    # uniq because *foo causes population of keys '*foo' and 'foo', with
    # ->[0] both being 'foo'. However, the keys are lowercase, not canonical.
    return List::Util::uniqstr map $_->[0], values %{ _read() };
}

sub balance($username) {
    return RevBank::Amount->parse_string( _read()->{ lc $username }->[1] );
}

sub since($username) {
    return _read()->{ lc $username }->[3];
}

sub create($username) {
    die "Account already exists" if exists _read()->{ lc $username };

    my $now = now();
    append $filename, "$username 0.00 $now\n";
    RevBank::Plugins::call_hooks("user_created", $username);
    return $username;
}

sub update($username, $delta, $transaction_id) {
    my $account = assert_user($username) or die "No such user ($username)";

    my $old = RevBank::Amount->new(0);
    my $new = RevBank::Amount->new(0);

    rewrite $filename, sub($line) {
        my @a = split " ", $line;
        if (lc $a[0] eq lc $account) {
            $old = RevBank::Amount->parse_string($a[1]);
            die "Fatal error: invalid balance in revbank:accounts:$.\n"
                if not defined $old;

            $new = $old + $delta;

            my $since = $a[3] // "";

            my $newc = $new->cents;
            my $oldc = $old->cents;
            $since = "+\@" . now() if $newc  > 0 and (!$since or $oldc <= 0);
            $since = "-\@" . now() if $newc  < 0 and (!$since or $oldc >= 0);
            $since = "0\@" . now() if $newc == 0 and (!$since or $oldc != 0);

            return sprintf "%-16s %9s %s %s\n", (
                $account, $new->string("+"), now(), $since
            );
        } else {
            return $line;
        }
    };

    RevBank::Plugins::call_hooks(
        "user_balance", $account, $old, $delta, $new, $transaction_id
    );
}

sub is_hidden($username) {
    return $username =~ /^[-+]/;
}

sub is_special($username) {
    return $username =~ /^[-+*]/;
}

sub parse_user($username, $allow_invalid = 0) {
    return undef if is_hidden($username);

    my $users = _read();

    my $user = $users->{ lc $username } or return undef;

    if ($user->[1] =~ /^!(.*)/) {
        warn "$username: Invalid account ($1).\n";
    }

    $allow_invalid or defined balance($username)
        or return undef;

    return $user->[0];
}

sub assert_user($username) {
    my $users = _read();

    my $user = $users->{ lc $username };

    if ($user) {
        Carp::croak("Account $username can't be used") if not balance $username;
        return $user->[0];
    }

    return create $username if is_hidden $username;

    Carp::croak("No such user ($username)")
}

1;


