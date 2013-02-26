package RevBank::Cart;
use strict;
use Carp ();
use List::Util ();
use RevBank::Global;

# Some code is written with the assumption that the card will only grow or
# be emptied. Changing existing stuff or removing items is probably not a
# good idea, and may lead to inconsistency.

sub new {
    my ($class) = @_;
    return bless { }, $class;
}

sub add {
    my ($self, $user, $amount, $description) = @_;
    $user ||= '$you';
    push @{ $self->{ $user } }, {
        amount => $amount,
        description => $description,
    };
}

sub empty {
    my ($self) = @_;
    %$self = ();
}

sub _dump_item {
    my ($prefix, $user, $amount, $description) = @_;
    return sprintf(
        "%s%-17s %4s EUR %5.2f  %s",
        $prefix,
        $user,
        ($amount > 0 ? 'GAIN' : $amount < 0 ? 'LOSE' : ''),
        abs($amount),
        $description
    );
}

sub as_strings {
    my ($self, $prefix) = @_;
    $prefix ||= '    ';

    my @s;

    for my $user (sort keys %$self) {
        my @items = @{ $self->{$user} };
        my $sum = List::Util::sum(map $_->{amount}, @items);

        push @s, _dump_item($prefix, $user, $_->{amount}, "# $_->{description}")
            for @items;
        push @s, _dump_item($prefix, $user, $sum, "TOTAL")
            if @items > 1;
    }

    return @s;
}

sub display {
    my ($self, $prefix) = @_;
    say $_ for $self->as_strings($prefix);
}

sub size {
    my ($self) = @_;
    return List::Util::sum(map scalar @{ $self->{$_} }, keys %$self) || 0;
}

sub _set_user {
    my ($self, $user) = @_;

    exists $self->{'$you'}
        or Carp::croak("Error: no cart items for shell user");

    $self->{$user} ||= [];

    push @{ $self->{$user} }, @{ delete $self->{'$you'} };

    for (values %$self) {
        $_->{description} =~ s/\$you\b/$user/g for @$_;
    }
}

sub checkout {
    my ($self, $user) = @_;

    $self->_set_user($user) if $user;

    exists $self->{'$you'} and die "Incomplete transaction; user not set.";

    my $transaction_id = time() - 1300000000;
    RevBank::Plugins::call_hooks("checkout", $self, $user, $transaction_id);

    for my $account (keys %$self) {
        my $sum = List::Util::sum(map $_->{amount}, @{ $self->{$account} });
        RevBank::Users::update($account, $sum, $transaction_id);
    }

    $self->empty;

    sleep 1;  # Ensure new timestamp/id for new transaction
}

sub select_items {
    my ($self, $regex) = @_;
    $regex ||= qr/(?:)/;  # Match everything if no regex is given

    my @matches;
    for my $user (keys %$self) {
        for my $item (@{ $self->{$user} }) {
            push @matches, { user => $user, %$item }
                if $item->{description} =~ /$regex/;
        }
    }

    return @matches;
}

1;

