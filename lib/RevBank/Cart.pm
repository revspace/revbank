package RevBank::Cart;
use strict;
use Carp ();
use List::Util ();
use RevBank::Global;

# Some code is written with the assumption that the cart will only grow or
# be emptied. Changing existing stuff or removing items is probably not a
# good idea, and may lead to inconsistency.

sub new {
    my ($class) = @_;
    return bless { items => {} }, $class;
}

sub add {
    my ($self, $user, $amount, $description, $data) = @_;
    $data ||= {};
    my $item = {
        %$data,  # Internal stuff, not logged or printed.
        amount => $amount,
        description => $description,
    };
    RevBank::Plugins::call_hooks("add", $self, $user, $item);
    push @{ $self->{items}{ $user || '$you' } }, $item;
    $self->{changed}++;
    RevBank::Plugins::call_hooks("added", $self, $user, $item);
}

sub delete {
    my ($self, $user, $index) = @_;
    splice @{ $self->{items}{ $user } }, $index, 1, ();
    $self->{changed}++;
}

sub empty {
    my ($self) = @_;
    %$self = (items => {});
    $self->{changed}++;
}

sub _dump_item {
    my ($prefix, $user, $amount, $description) = @_;
    return sprintf(
        "%s%-12s %4s EUR %5.2f  %s",
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

    my $items = $self->{items};
    for my $user (sort keys %$items) {
        my @items = @{ $items->{$user} };
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
    my $items = $self->{items};
    return List::Util::sum(map scalar @{ $items->{$_} }, keys %$items) || 0;
}

sub _set_user {
    my ($self, $user) = @_;
    my $items = $self->{items};

    exists $items->{'$you'}
        or Carp::croak("Error: no cart items for shell user");

    $items->{$user} ||= [];

    push @{ $items->{$user} }, @{ delete $items->{'$you'} };

    for (values %$items) {
        $_->{description} =~ s/\$you\b/$user/g for @$_;
    }
}

sub checkout {
    my ($self, $user) = @_;

    $self->_set_user($user) if $user;
    my $items = $self->{items};

    exists $items->{'$you'} and die "Incomplete transaction; user not set.";

    my $transaction_id = time() - 1300000000;
    RevBank::Plugins::call_hooks("checkout", $self, $user, $transaction_id);

    for my $account (keys %$items) {
        my $sum = List::Util::sum(map $_->{amount}, @{ $items->{$account} });
        RevBank::Users::update($account, $sum, $transaction_id);
    }

    $self->empty;

    sleep 1;  # Ensure new timestamp/id for new transaction
}

sub select_items {
    my ($self, $key) = @_;
    my $items = $self->{items};

    my @matches;
    for my $user (keys %$items) {
        for my $item (@{ $items->{$user} }) {
            push @matches, { user => $user, %$item }
                if @_ == 1  # No key or match given: match everything
                or @_ == 2 and exists $item->{ $key }   # Just a key
        }
    }

    return @matches;
}

sub is_multi_user {
    my ($self) = @_;
    return keys(%{ $self->{items} }) > 1;
}

sub changed {
    my ($self) = @_;
    return delete $self->{changed};
}

1;

