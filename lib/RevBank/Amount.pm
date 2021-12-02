package RevBank::Amount;
use v5.28;
use warnings;
use experimental qw(signatures);
use Carp qw(carp croak);
use Scalar::Util;
use POSIX qw(lround);

our $C = __PACKAGE__;

sub _coerce {
    for (@_) {
        unless (ref and UNIVERSAL::isa($_, $C)) {
            croak "Unsupported operation on $C with " . ref if ref;
            croak "Unsupported operation on $C with undef" if not defined;

            my $old = $_;

            $_ = RevBank::Amount->parse_string("$_");
            croak "Unsupported operation on $C with invalid amount '$old'"
                if not defined;
        }
    }
}

use overload (
    '""'   => sub ($self, @) { $self->string },
    "bool" => sub ($self, @) { $self->cents },
    "0+"   => sub ($self, @) { $self->_float_warn },
    "+" => sub ($a, $b, $swap) {
        $b //= 0;
        _coerce($a, $b);
        return $C->new($$a + $$b)
    },
    "-" => sub ($a, $b, $swap) {
        _coerce($a, $b);
        return $C->new(($swap?-1:1) * ($$a - $$b))
    },
    "*" => sub ($a, $b, $swap) {
        $b = $b->_float_warn if ref $b;
        $C->new($$a * $b);
    },
    "/" => sub ($a, $b, $swap) {
        carp "Using floating-point arithmetic for $a/$b (use \$amount->float to suppress warning)";
        $b = $b->float if ref $b;
        $C->new($$a / $b);
    },
    "<=>" => sub ($a, $b, $swap) {
        _coerce($a, $b);
        return $swap ? $$b<=>$$a : $$a<=>$$b;
    },
    "cmp" => sub ($a, $b, $swap) {
        _coerce($a, $b);
        return $swap ? $$b<=>$$a : $$a<=>$$b;
    },
);

sub new($class, $cents) {
    my $int = int sprintf "%d", $cents;
    #carp "$cents rounded to $int cents" if $int != $cents;
    return bless \$int, $class;
}

sub new_from_float($class, $num) {
    return $class->new(lround 100 * sprintf "%.02f", $num);

    # First, round the float with sprintf for bankers rounding, then
    # multiply to get number of cents. However, 4.56 as a float is
    # 4.55999... which with int would get truncated to 455, so lround is needed
    # to get 456.
    # Note: _l_round, because normal round gives the int *AS A FLOAT*; sigh.
}

sub parse_string($class, $str) {
    $str =~ /\S/ or return undef;

    my ($neg, $int, $cents)
        = $str =~ /^\s*(?:\+|(-)?)([0-9]+)?(?:[,.]([0-9]{1,2}))?\s*$/
        or return undef;

    $int //= 0;
    $cents //= 0;
    $cents *= 10 if length($cents) == 1;  # 4.2 -> 4.20

    return $class->new(
        ($neg ? -1 : 1) * ($int * 100 + $cents)
    );
}

sub cents($self) {
    return $$self;
}

sub float($self) {
    return $$self / 100;
}

sub _float_warn($self) {
    carp "Using $C $self as floating-point number (use %s in sprintf instead of %.2f, or \$amount->float to suppress warning)";
    return $self->float;
}

sub string($self, $plus = "") {
    return sprintf(
        "%s%d.%02d",
        $$self < 0 ? "-" : $plus,
        abs($$self) / 100,
        abs($$self) % 100,
    );
}

sub string_flipped($self, $sep = " ") {
    return sprintf(
        "%s%s%d.%02d",
        $$self > 0 ? "+" : "",
        $sep,
        abs($$self) / 100,
        abs($$self) % 100,
    );
}

sub abs($self) {
    return $C->new(abs $$self)
}

1;
