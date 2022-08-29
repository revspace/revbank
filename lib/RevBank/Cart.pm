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
    RevBank::Plugins::call_hooks("added_entry", $self, $entry);

    return $entry;
}

sub add($self, $amount, $description, $data = {}) {
    Carp::croak "Unitialized amount; possibly a deprecated call style (\$cart->add(undef, ...))"
        if not defined $amount;
    Carp::croak "Non-hash data argument; possibly a deprecated call style (\$cart->add(\$user, ...)"
        if @_ == 4 and not ref $data;
    Carp::croak "Missing description; possibly a deprecated call style (\$cart->add(\$entry); use add_entry instead)"
        if not defined $description;

    return $self->add_entry(RevBank::Cart::Entry->new($amount, $description, $data));
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

    my %deltas;
    for my $entry (@$entries) {
        $entry->sanity_check;

        $entry->user($user);

        $deltas{$entry->{user}} //= RevBank::Amount->new(0);
        $deltas{$_->{user}} += $_->{amount} * $entry->quantity
            for $entry, $entry->contras;
    }

    my $transaction_id = time() - 1300000000;

    RevBank::FileIO::with_lock {
        RevBank::Plugins::call_hooks("checkout", $self, $user, $transaction_id);

        for my $account (reverse sort keys %deltas) {
            # The reverse sort is a lazy way to make the "-" accounts come last,
            # which looks nicer with the "cash" plugin.
            RevBank::Users::update($account, $deltas{$account}, $transaction_id)
                if $deltas{$account} != 0;
        }

        RevBank::Plugins::call_hooks("checkout_done", $self, $user, $transaction_id);
    };

    $self->empty;

    sleep 1;  # Ensure new timestamp/id for new transaction
    return 1;
}

sub entries($self, $attribute = undef) {
    my @entries = @{ $self->{entries} };
    return grep $_->has_attribute($attribute), @entries if defined $attribute;
    return @entries;
}

sub changed($self) {
    my $changed = 0;
    for my $entry ($self->entries('changed')) {
        $entry->attribute('changed', undef);
        $changed = 1;
    }
    $changed = 1 if delete $self->{changed};
    return $changed;
}

sub sum($self) {
    return List::Util::sum(map $_->{amount} * $_->quantity, @{ $self->{entries} });
}

1;
