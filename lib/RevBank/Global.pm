package RevBank::Global;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since v5.36

use POSIX qw(strftime);
use RevBank::Amount;
use RevBank::FileIO;

{
    package RevBank::Exception::RejectInput;
    sub new($class, $reason) { return bless \$reason, $class; }
    sub reason($self) { return $$self; }
}

sub _parse_any_amount($amount) {
    defined $amount or return undef;
    length  $amount or return undef;

    my @split = grep /\S/, split /([+-])/, $amount;

    my $posneg = 1;
    $amount = RevBank::Amount->new(0);
    for my $token (@split) {
        if ($token eq '-') {
            $posneg = $posneg == -1 ? 1 : -1;
        } elsif ($token eq '+') {
            $posneg ||= 1;
        } else {
            $posneg or return undef;  # two terms in a row
            my $term = RevBank::Amount->parse_string($token) // return undef;
            $amount += $posneg * $term;
            $posneg = 0;
        }
    }
    $posneg and return undef;  # last token must be term

    return $amount;

}

sub import {
    require RevBank::Plugins;
    require RevBank::Users;
    no strict 'refs';
    my $caller = caller;
    *{"$caller\::ACCEPT"}       = sub () { \1 };
    *{"$caller\::ABORT"}        = sub () { \2 };
    *{"$caller\::REJECT"}       = sub () { \3 };
    *{"$caller\::NEXT"}         = sub () { \4 };
    *{"$caller\::DONE"}         = sub () { \5 };
    *{"$caller\::REDO"}         = sub () { \6 };
    *{"$caller\::slurp"}        = \&RevBank::FileIO::slurp;
    *{"$caller\::spurt"}        = \&RevBank::FileIO::spurt;
    *{"$caller\::rewrite"}      = \&RevBank::FileIO::rewrite;
    *{"$caller\::append"}       = \&RevBank::FileIO::append;
    *{"$caller\::with_lock"}    = \&RevBank::FileIO::with_lock;
    *{"$caller\::parse_user"}   = \&RevBank::Users::parse_user;
    *{"$caller\::parse_any_amount"} = \&_parse_any_amount;
    *{"$caller\::parse_amount" } = sub ($amount) {
        $amount = _parse_any_amount($amount) // return undef;

        if ($amount->cents < 0) {
            die RevBank::Exception::RejectInput->new(
                "For our sanity, no negative amounts, please :)."
            );
        }
        if ($amount->cents > 99900) {
            die RevBank::Exception::RejectInput->new(
                "That's way too much money."
            );
        }
        return $amount;
    };
    *{"$caller\::call_hooks"} = \&RevBank::Plugins::call_hooks;
    *{"$caller\::say"} = sub {
        print @_, "\n";
    };
    *{"$caller\::now"} = sub () {
        return strftime '%Y-%m-%d_%H:%M:%S', localtime;
    };

}

__PACKAGE__->import;

1;
