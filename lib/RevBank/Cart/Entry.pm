use strict;

package RevBank::Cart::Entry;

use Carp qw(carp croak);
use List::Util ();

sub new {
    my ($class, $amount, $description, $attributes) = @_;

    @_ >= 3 or croak "Not enough arguments for RevBank::Cart::Entry->new";
    $attributes //= {};

    $amount = RevBank::Amount->parse_string($amount) if not ref $amount;

    my $self = {
        quantity    => 1,
        amount      => $amount,  # negative = pay, positive = add money
        description => $description,
        attributes  => { %$attributes },
        user        => undef,
        contras     => [],
        caller      => (caller 1)[3],
    };

    return bless $self, $class;
}

sub add_contra {
    my ($self, $user, $amount, $description) = @_;

    $amount = RevBank::Amount->parse_string($amount) if not ref $amount;

    $description =~ s/\$you/$self->{user}/g if defined $self->{user};

    push @{ $self->{contras} }, {
        user        => $user,
        amount      => $amount,  # should usually have opposite sign (+/-)
        description => $description,
    };

    $self->attribute('changed', 1);
}

sub has_attribute {
    my ($self, $key) = @_;

    return (
        exists      $self->{attributes}->{$key}
        and defined $self->{attributes}->{$key}
    );
}

sub attribute {
    my ($self, $key, $new) = @_;

    my $ref = \$self->{attributes}->{$key};
    $$ref = $new if @_ > 2;
    return $$ref;
}

sub quantity {
    my ($self, $new) = @_;

    my $ref = \$self->{quantity};
    if (defined $new) {
        $new >= 0 or croak "Quantity must be positive";
        $$ref = $new;
        $self->attribute('changed', 1);
    }

    return $$ref;
}

sub multiplied {
    my ($self) = @_;

    return $self->{quantity} != 1;
}

sub contras {
    my ($self) = @_;

    # Shallow copy suffices for now, because there is no depth.
    return map +{ %$_ }, @{ $self->{contras} };
}

sub as_printable {
    my ($self) = @_;

    $self->sanity_check;

    my @s;
    push @s, $self->{quantity} . "x {" if $self->multiplied;

    # Normally, the implied sign is "+", and an "-" is only added for negative
    # numbers. Here, the implied sign is "-", and a "+" is only added for
    # positive numbers.
    push @s, sprintf "  %6s %s", $self->{amount}->string_flipped, $self->{description};

    for my $c ($self->contras) {
        push @s, sprintf(
            "  %9s %s %s",
            $c->{amount}->abs->string,
            ($c->{amount}->cents > 0 ? "->" : "<-"),
            $c->{user}
        );

    }

    push @s, "}" if $self->multiplied;

    return @s;
}

sub as_loggable {
    my ($self) = @_;

    croak "Loggable called before set_user" if not defined $self->{user};
    $self->sanity_check;

    my $quantity = $self->{quantity};

    my @s;
    for ($self, @{ $self->{contras} }) {
        my $total = $quantity * $_->{amount};

        my $description =
            $quantity == 1
            ? $_->{description}
            : sprintf("%s [%sx %s]", $_->{description}, $quantity, abs($_->{amount}));

        push @s, sprintf(
            "%-12s %4s %3d %5s  # %s",
            $_->{user},
            ($total > 0 ? 'GAIN' : $total < 0 ? 'LOSE' : ''),
            $quantity,
            abs($total),
            $description
        );
    }

    return @s;
}

sub user {
    my ($self, $new) = @_;

    if (defined $new) {
        croak "User can only be set once" if defined $self->{user};

        $self->{user} = $new;
        $_->{description} =~ s/\$you/$new/g for $self, @{ $self->{contras} };
    }

    return $self->{user};
}

sub sanity_check {
    my ($self) = @_;

    # Turnover and journals are implicit contras, so (for now) a zero sum is
    # not required. However, in a transaction with contras, one should at least
    # not try to issue money that does not exist.

    return 1 if $self->{FORCE};
    my @contras = $self->contras or return 1;

    my $sum = List::Util::sum(map $_->{amount}->cents, $self, @contras);

    if ($sum > 0) {
        $self->{FORCE} = 1;
        croak join("\n",
            "BUG! (probably in $self->{caller})",
            "This adds up to creating money that does not exist:",
            $self->as_printable,
            (
                $sum == 2 * $self->{amount}->cents
                ? "Hint: contras for positive value should be negative values."
                : ()
            ),
            sprintf("Cowardly refusing to create $sum out of thin air")
        );
    }

    return 1;
}

1;
