package RevBank::Accounts;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since v5.36

use RevBank::Global;
use RevBank::Plugins;
use Carp qw(croak);
use List::Util ();

my $filename = "accounts";

sub _read() {
    my @accounts;

    my @lines = with_lock sub {
        my $file = slurp $filename;

        # Fix broken format: append newline if absent
        if (length($file) and $file !~ /\n\z/) {
            append $filename, "\n";
        }
        return split /\n+/, $file;
    };

    for my $line (@lines) {
        $line =~ /\S/ or next;
        # Not using RevBank::Prompt::split_input to keep parsing by external
        # scripts simple, since so many such scripts exist.

        my @split = split " ", $line;

        if ($split[1] =~ /^!/) {
            # Special case: use rest of the line (see POD).
            @split = split " ", $line, 2;
        }

        push @accounts, \@split;
    }

    my %accounts;
    for (@accounts) {
        my $name = lc $_->[0];

        exists $accounts{$name} and die "$filename: duplicate entry '$name'\n";
        $accounts{$name} = $_;

        if ($name =~ s/^\*//) {
            # user-accessible special account: support without * prefix
            exists $accounts{$name} and die "$filename: duplicate entry '$name'\n";
            $accounts{$name} = $_;
        }
    }

    return \%accounts;
}

sub names() {
    # uniq because *foo causes population of keys '*foo' and 'foo', with
    # ->[0] both being 'foo'. However, the keys are lowercase, not canonical.
    return List::Util::uniqstr map $_->[0], values %{ _read() };
}

sub balance($account) {
    return RevBank::Amount->parse_string( _read()->{ lc $account }->[1] );
}

sub since($account) {
    return _read()->{ lc $account }->[3];
}

sub create($account) {
    croak "Account already exists" if exists _read()->{ lc $account };

    my $now = now();
    append $filename, "$account 0.00 $now\n";
    RevBank::Plugins::call_hooks("user_created", $account);  # until 2027-05-01
    RevBank::Plugins::call_hooks("account_created", $account);
    return $account;
}

sub delete($account) {
    croak "Deleting special account not supported" if RevBank::Accounts::is_special $account;
    $account = assert_account($account);

    with_lock {
        balance($account)->cents == 0 or croak "Account still has balance";

        rewrite $filename, sub($line) {
            my @a = split " ", $line;
            return "" if $a[0] eq $account;
            return $line;
        };
    };

    call_hooks("account_deleted", $account);
    return $account;
}

sub update($account, $delta, $transaction_id) {
    $account = assert_account($account);

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
        # Backwards compatibility until 2027-05-01
        "user_balance", $account, $old, $delta, $new, $transaction_id
    );
    RevBank::Plugins::call_hooks(
        "account_balance", $account, $old, $delta, $new, $transaction_id
    );
}

sub is_hidden($account) {
    return $account =~ /^[-+]/;
}

sub is_special($account) {
    return $account =~ /^[-+*]/;
}

sub parse_user($username, $allow_invalid = 0) {
    return undef if is_hidden($username);

    my $accounts = _read();

    my $user = $accounts->{ lc $username } or return undef;

    if ($user->[1] =~ /^!(.*)/) {
        warn "$username: Invalid account ($1).\n";
    }

    $allow_invalid or defined balance($username)
        or return undef;

    return $user->[0];
}

sub assert_account($account) {
    my $accounts = _read();

    my $account_info = $accounts->{ lc $account };

    if ($account_info) {
        croak "Account $account can't be used" if not defined balance $account;
        return $account_info->[0];
    }

    return create $account if is_hidden $account;

    croak "No such user ($account)";
}

# Backwards compatibility until 2027-05-01
*RevBank::Users::names        = \&RevBank::Accounts::names;
*RevBank::Users::balance      = \&RevBank::Accounts::balance;
*RevBank::Users::since        = \&RevBank::Accounts::since;
*RevBank::Users::create       = \&RevBank::Accounts::create;
*RevBank::Users::update       = \&RevBank::Accounts::update;
*RevBank::Users::is_hidden    = \&RevBank::Accounts::is_hidden;
*RevBank::Users::is_special   = \&RevBank::Accounts::is_special;
*RevBank::Users::parse_user   = \&RevBank::Accounts::parse_user;
*RevBank::Users::assert_user  = \&RevBank::Accounts::assert_account;

1;


