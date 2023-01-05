package RevBank::Cart::Entry;

use v5.28;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use Carp qw(carp croak);
use RevBank::Users;
use List::Util ();

sub new($class, $amount, $description, $attributes = {}) {
    $amount = RevBank::Amount->parse_string($amount) if not ref $amount;

    my $self = {
        quantity    => 1,
        amount      => $amount,  # negative = pay, positive = add money
        description => $description,
        attributes  => { %$attributes },
        user        => undef,
        contras     => [],  # infos + contras
        caller      => List::Util::first(sub { !/^RevBank::Cart/ }, map { (caller $_)[3] } 1..10)
                       || (caller 1)[3],
    };

    return bless $self, $class;
}

sub add_contra($self, $user, $amount, $description) {
    $amount = RevBank::Amount->parse_string($amount) if not ref $amount;
    $user = RevBank::Users::assert_user($user);

    $description =~ s/\$you/$self->{user}/g if defined $self->{user};

    push @{ $self->{contras} }, {
        user        => $user,
        amount      => $amount,  # should usually have opposite sign (+/-)
        description => $description,
    };

    $self->attribute('changed', 1);

    return $self;  # for method chaining
}

sub add_info($self, $amount, $description) {
    $amount = RevBank::Amount->parse_string($amount) if not ref $amount;

    $description =~ s/\$you/$self->{user}/g if defined $self->{user};

    push @{ $self->{contras} }, {
        user        => undef,
        amount      => $amount,  # should usually have SAME sign (+/-)
        description => $description,
    };

    $self->attribute('changed', 1);

    return $self;  # for method chaining
}

sub has_attribute($self, $key) {
    return (
        exists      $self->{attributes}->{$key}
        and defined $self->{attributes}->{$key}
    );
}

sub attribute($self, $key, $new = undef) {
    my $ref = \$self->{attributes}->{$key};
    $$ref = $new if @_ > 2;
    return $$ref;
}

sub amount($self, $new = undef) {
    my $ref = \$self->{amount};
    if (defined $new) {
        $new = RevBank::Amount->parse_string($new) if not ref $new;
        $$ref = $new;
        $self->attribute('changed', 1);
    }

    return $$ref;
}

sub quantity($self, $new = undef) {
    my $ref = \$self->{quantity};
    if (defined $new) {
        $new >= 0 or croak "Quantity must be positive";
        $$ref = $new;
        $self->attribute('changed', 1);
    }

    return $$ref;
}

sub multiplied($self) {
    return $self->{quantity} != 1;
}

sub contras($self) {
    # Shallow copy suffices for now, because there is no depth.
    return map +{ %$_ }, grep defined $_->{user}, @{ $self->{contras} };
}

sub as_printable($self) {
    my @s;
    push @s, $self->{quantity} . "x {" if $self->multiplied;

    # Normally, the implied sign is "+", and an "-" is only added for negative
    # numbers. Here, the implied sign is "-", and a "+" is only added for
    # positive numbers.
    push @s, sprintf "%8s %s", $self->{amount}->string_flipped, $self->{description};

    for my $c (@{ $self->{contras} }) {
        my $description;
        if (defined $c->{user}) {
            next if RevBank::Users::is_hidden($c->{user}) and not $ENV{REVBANK_DEBUG};
            $description = join " ", ($c->{amount}->cents > 0 ? "->" : "<-"), $c->{user};
        } else {
            $description = $c->{description};
        }
        push @s, sprintf(
            "%11s %s",
            ($self->{amount} > 0 ? $c->{amount}->string_flipped("") : $c->{amount}->string),
            $description
        );
    }

    push @s, "}" if $self->multiplied;

    return @s;
}

sub as_loggable($self) {
    croak "Loggable called before set_user" if not defined $self->{user};

    my $quantity = $self->{quantity};

    my @s;
    for ($self, @{ $self->{contras} }) {
        next if not defined $_->{user};
        my $total = $quantity * $_->{amount};

        my $description =
            $quantity == 1
            ? $_->{description}
            : sprintf("%s [%sx %s]", $_->{description}, $quantity, $_->{amount}->abs);

        push @s, sprintf(
            "%-12s %4s %3d %6s  # %s",
            $_->{user},
            ($total->cents > 0 ? 'GAIN' : $total->cents < 0 ? 'LOSE' : '===='),
            $quantity,
            $total->abs,
            $description
        );
    }

    return @s;
}

sub user($self, $new = undef) {
    if (defined $new) {
        croak "User can only be set once" if defined $self->{user};

        $self->{user} = $new;
        $_->{description} =~ s/\$you/$new/g for $self, @{ $self->{contras} };
    }

    return $self->{user};
}

sub sanity_check($self) {
    # Turnover and journals were implicit contras in previous versions of
    # revbank, but old plugins may need upgrading to the new dual-entry system,
    # so (for now) a zero sum is not required.

    my @contras = $self->contras;

    my $sum = RevBank::Amount->new(
        List::Util::sum(map $_->{amount}->cents, $self, @contras)
    );

    # Although unbalanced transactiens are still allowed, a transaction with
    # contras should at least not try to issue money that does not exist.
    if ($sum > 0 and @contras and not $self->{FORCE_UNBALANCED}) {
        local $ENV{REVBANK_DEBUG} = 1;
        my $message = join("\n",
            "BUG! (probably in $self->{caller})",
            "This adds up to creating money that does not exist:",
            $self->as_printable,
            (
                $sum == 2 * $self->{amount}
                ? "Hint for the developer: contras for positive value should be negative values and vice versa."
                : ()
            ),
            "Cowardly refusing to create $sum out of thin air"
        );
        RevBank::Plugins::call_hooks("log_error", "UNBALANCED ENTRY $message");
        croak $message;
    }

    if ($sum != 0) {
        local $ENV{REVBANK_DEBUG} = 1;
        my $forced = $self->{FORCE_UNBALANCED} ? " (FORCED)" : "";
        RevBank::Plugins::call_hooks(
            "log_warning",
            "UNBALANCED ENTRY$forced in $self->{caller}: " . (
                @contras
                ? "sum of entry with contras ($sum) != 0.00"
                : "transaction has no contras"
            ) . ". This will probably be a fatal error in a future version of revbank.\n"
            . "The unbalanced entry is:\n" . join("\n", $self->as_printable)
        )
    }

    return 1;
}

1;
