package RevBank::Cart;

use v5.28;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use Carp ();
use List::Util ();
use RevBank::Global;
use RevBank::Users;
use RevBank::FileIO;
use RevBank::Cart::Entry;

sub new($class) {
    return bless { entries => [] }, $class;
}

sub add_entry($self, $entry) {
    RevBank::Plugins::call_hooks("add_entry", $self, $entry);

    push @{ $self->{entries} }, $entry;
    $self->{changed}++;
    $self->select($entry);

    RevBank::Plugins::call_hooks("added_entry", $self, $entry);

    return $entry;
}

sub add($self, $amount, $description, $data = {}) {
    Carp::croak "Non-hash data argument; possibly a deprecated call style"
        if not ref $data;

    # Old pre-v3 call styles:
    # ->add(undef, ...)  => just remove the "undef,"
    # ->add($user, ...)  => use $cart->add(...)->add_contra($user, ...)
    # ->add($entry)      => use $cart->add_entry($entry)

    return $self->add_entry(RevBank::Cart::Entry->new($amount, $description, $data));
}

sub select($self, $entry) {
    return $self->{selected_entry} = $entry;
}

sub selected($self) {
    return undef if not @{ $self->{entries} };

    for my $entry (@{ $self->{entries} }) {
        return $entry if $entry == $self->{selected_entry};
    }

    return $self->select( $self->{entries}->[-1] );
}

sub delete($self, $entry) {
    my $entries = $self->{entries};

    my $oldnum = @$entries;
    @$entries = grep $_ != $entry, @$entries;
    $self->{changed}++;

    return $oldnum - @$entries;
}

sub empty($self) {
    $self->{entries} = [];
    $self->{changed}++;
}

sub display($self, $prefix = "") {
    say "$prefix$_" for map $_->as_printable, @{ $self->{entries} };
}

sub size($self) {
    return scalar @{ $self->{entries} };
}

sub checkout($self, $user) {
    if ($self->entries('refuse_checkout')) {
        warn "Refusing to finalize deficient transaction.\n";
        $self->display;
        return;
    }

    $user = RevBank::Users::assert_user($user);

    my $entries = $self->{entries};

    for my $entry (@$entries) {
        $entry->sanity_check;
        $entry->user($user);
    }

    RevBank::FileIO::with_lock {
        my $transaction_id = time() - 1300000000;

        RevBank::Plugins::call_hooks("checkout_prepare", $self, $user, $transaction_id);
        for my $entry (@$entries) {
            $entry->sanity_check;
            $entry->user($user) if not $entry->user;
        }

        RevBank::Plugins::call_hooks("checkout", $self, $user, $transaction_id);

        my %deltas = ($user => RevBank::Amount->new(0));

        for my $entry (@$entries) {
            $deltas{$_->{user}} += $_->{amount} * $entry->quantity
                for $entry, $entry->contras;
        }

        for my $account (reverse sort keys %deltas) {
            # The reverse sort is a lazy way to make the "-" accounts come last,
            # which looks nicer with the "cash" plugin.
            RevBank::Users::update($account, $deltas{$account}, $transaction_id)
                if $deltas{$account} != 0;
        }

        RevBank::Plugins::call_hooks("checkout_done", $self, $user, $transaction_id);

        sleep 1;  # look busy (and ensure new id for next transaction :))
    };

    $self->empty;

    return 1;
}

sub entries($self, $attribute = undef) {
    my @entries = @{ $self->{entries} };
    return grep $_->has_attribute($attribute), @entries if defined $attribute;
    return @entries;
}

sub changed($self, $keep = 0) {
    my $changed = 0;
    for my $entry ($self->entries('changed')) {
        $entry->attribute('changed', undef) unless $keep;
        $changed = 1;
    }
    $changed = 1 if $self->{changed};
    delete $self->{changed} unless $keep;

    return $changed;
}

sub sum($self) {
    return List::Util::sum(map $_->{amount} * $_->quantity, @{ $self->{entries} });
}

1;
