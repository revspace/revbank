package RevBank::Users;

use v5.28;
use warnings;
use experimental 'signatures';  # stable since v5.36

use RevBank::Global;
use RevBank::Plugins;
use Carp ();
use List::Util ();

my $filename = "revbank.accounts";

sub _read() {
    my @users;
    /\S/ and push @users, [split " "] for slurp $filename;

    my %users;
    for (@users) {
        my $name = $_->[0];
        if ($name =~ /^\*/) {
            # user-accessible special account: support without * prefix
            $users{ lc($name) =~ s/^\*//r } = $_;

            # also support literal account name with * prefix
            $users{ lc($name) } = $_;
        } else {
            # hidden or normal account
            $users{ lc($name) } = $_;
        }
    }
    return \%users;
}

sub names() {
    return List::Util::uniqstr map $_->[0], values %{ _read() };
}

sub balance($username) {
    return RevBank::Amount->parse_string( _read()->{ lc $username }->[1] );
}

sub since($username) {
    return _read()->{ lc $username }->[3];
}

sub create($username) {
    my $now = now();
    append $filename, "$username 0.00 $now\n";
    RevBank::Plugins::call_hooks("user_created", $username);
    return $username;
}

sub update($username, $delta, $transaction_id) {
    my $old = RevBank::Amount->new(0);
    my $new = RevBank::Amount->new(0);

    rewrite $filename, sub($line) {
        my @a = split " ", $line;
        if (lc $a[0] eq lc $username) {
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
                $username, $new->string("+"), now(), $since
            );
        } else {
            return $line;
        }
    };

    RevBank::Plugins::call_hooks(
        "user_balance", $username, $old, $delta, $new, $transaction_id
    );
}

sub is_hidden($username) {
    return $username =~ /^[-+]/;
}

sub is_special($username) {
    return $username =~ /^[-+*]/;
}

sub parse_user($username) {
    return undef if is_hidden($username);

    my $users = _read();
    return exists $users->{ lc $username }
        ? $users->{ lc $username }->[0]
        : undef;
}

sub assert_user($username) {
    my $users = _read();

    return exists $users->{ lc $username }
        ? $users->{ lc $username }->[0]
        : (is_hidden($username)
            ? create($username)
            : Carp::croak("Account '$username' does not exist")
        );
}

1;


