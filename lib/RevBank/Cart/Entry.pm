use strict;

package RevBank::Cart::Entry;

use Carp qw(carp croak);
use List::Util ();

sub new {
    my ($class, $amount, $description, $attributes) = @_;

    @_ >= 3 or croak "Not enough arguments for RevBank::Cart::Entry->new";
    $attributes //= {};

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

    $description =~ s/\$you/$self->{user}/g if defined $self->{user};

    push @{ $self->{contras} }, {
        user        => $user,
        amount      => $amount,  # should usually have opposite sign (+/-)
        description => $description,
    };
}

sub has_attribute {
    my ($self, $key) = @_;

    return exists $self->{attributes}->{$key};
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
    }

    return $$ref;
}

sub multiple {
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
    push @s, $self->{quantity} . "x {" if $self->multiple;

    # Normally, the implied sign is "+", and an "-" is only added for negative
    # numbers. Here, the implied sign is "-", and a "+" is only added for
    # positive numbers.
    push @s, sprintf "  %7.2f %s", abs($self->{amount}), $self->{description};

    # Add the plus before the number instead of whitespace, leaving one space
    # character between the sign and the number to make it stand out more.
    $s[-1] =~ s/\s(?=\s\d)/+/ if $self->{amount} > 0;

    for my $c ($self->contras) {
        push @s, sprintf(
            "   %9.2f %s %s",
            abs($c->{amount}),
            ($c->{amount} > 0 ? "->" : "<-"),
            $c->{user}
        );

    }

    push @s, "}" if $self->multiple;

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
            : sprintf("[%fx%.2f]", $quantity, $_->{amount});

        push @s, sprintf(
            "%-12s %4s EUR %5.2f  %s",
            $_->{user},
            ($total > 0 ? 'GAIN' : $total < 0 ? 'LOSE' : ''),
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

    return 1 if $self->{force};
    my @contras = $self->contras or return 1;

    my $amount = List::Util::sum(map $_->{amount}, $self, @contras);

    if ($amount >= 0.005) {  # meh, floats
        $self->{force} = 1;
        croak join("\n",
            "BUG! (probably in $self->{caller})",
            "This adds up to creating money that does not exist:",
            $self->as_printable,
            (
                $amount == 2 * $self->{amount}
                ? "Hint: contras for positive value should be negative values."
                : ()
            ),
            sprintf("Cowardly refusing to create %.2f out of thin air", $amount)
        );
    }

    return 1;
}

1;
