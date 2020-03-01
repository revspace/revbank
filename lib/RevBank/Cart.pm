package RevBank::Cart;
use strict;
use Carp ();
use List::Util ();
use RevBank::Global;
use RevBank::Cart::Entry;

sub new {
    my ($class) = @_;
    return bless { entries => [] }, $class;
}

sub add_entry {
    my ($self, $entry) = @_;

    $self->_call_old_hooks("add", $entry);
    RevBank::Plugins::call_hooks("add_entry", $self, $entry);

    push @{ $self->{entries} }, $entry;
    $self->{changed}++;
    $self->_call_old_hooks("added", $entry);
    RevBank::Plugins::call_hooks("added_entry", $self, $entry);

    return $entry;
}

sub add {
    # Deprecated interface: ->add($user, ...)
    if (defined $_[3] and not ref $_[3]) {
        return shift->old_add(@_);
    }

    # ->add($entry)
    if (@_ == 2) {
        my ($self, $entry) = @_;
        return $self->add_entry($entry);
    }

    # ->add($amount, ...)
    my ($self, $amount, $description, $data) = @_;
    return $self->add_entry(RevBank::Cart::Entry->new($amount, $description, $data));
}

sub delete {
    Carp::croak("\$cart->delete(\$user, \$index) is no longer supported") if @_ > 2;

    my ($self, $entry) = @_;
    my $entries = $self->{entries};

    my $oldnum = @$entries;
    @$entries = grep $_ != $entry, @$entries;
    $self->{changed}++;

    return $oldnum - @$entries;
}

sub empty {
    my ($self) = @_;

    $self->{entries} = [];
    $self->{changed}++;
}

sub display {
    my ($self, $prefix) = @_;
    $prefix //= "";
    say "$prefix$_" for map $_->as_printable, @{ $self->{entries} };
}

sub size {
    my ($self) = @_;
    return scalar @{ $self->{entries} };
}

sub checkout {
    my ($self, $user) = @_;

    if ($self->entries('refuse_checkout')) {
        warn "Refusing to finalize deficient transaction.\n";
        $self->display;
        return;
    }

    my $entries = $self->{entries};

    my %deltas;
    for my $entry (@$entries) {
        $entry->user($user);

        $deltas{$_->{user}} += $_->{amount} * $entry->quantity
            for $entry, $entry->contras;
    }

    my $transaction_id = time() - 1300000000;
    RevBank::Plugins::call_hooks("checkout", $self, $user, $transaction_id);

    for my $account (keys %deltas) {
        RevBank::Users::update($account, $deltas{$account}, $transaction_id)
            if $deltas{$account} != 0;
    }

    RevBank::Plugins::call_hooks("checkout_done", $self, $user, $transaction_id);

    $self->empty;

    sleep 1;  # Ensure new timestamp/id for new transaction
    return 1;
}

sub entries {
    my ($self, $attribute) = @_;

    my @entries = @{ $self->{entries} };
    return grep $_->has_attribute($attribute), @entries if defined $attribute;
    return @entries;
}

sub changed {
    my ($self) = @_;

    my $changed = 0;
    for my $entry ($self->entries('changed')) {
        $entry->attribute('changed', undef);
        $changed = 1;
    }
    $changed = 1 if delete $self->{changed};
    return $changed;
}

sub sum {
    my ($self) = @_;
    return List::Util::sum(map $_->{amount} * $_->quantity, @{ $self->{entries} });
}


### Old stuff, to be deleted in a future version:

sub _call_old_hooks {
    my ($self, $hook, $entry) = @_;

    my $data = $entry->{attributes};

    for (1 .. $entry->quantity) {
        for ($entry, $entry->contras) {
            my $item = {
                %$data,
                amount => $_->{amount},
                description => $_->{description},
            };

            RevBank::Plugins::call_hooks($hook, $self, $_->{user}, $item);
        }
    }
}

sub as_strings {
    my ($self) = @_;
    Carp::carp("Plugin uses deprecated \$cart->as_strings");

    return map $_->as_loggable, @{ $self->{entries} };
}

sub is_multi_user {
    Carp::carp("\$cart->is_multi_user is no longer supported, ignoring");
}

sub select_items {
    my ($self, $key) = @_;
    Carp::carp("Plugin uses deprecated \$cart->select_items");

    my @matches;
    for my $entry (@{ $self->{entries} }) {
        my %attributes = %{ $entry->{attributes} };
        for (1 .. $entry->quantity) {
            for my $item ($entry, $entry->contras) {
                push @matches, { %attributes, %$item }
                    if @_ == 1  # No key or match given: match everything
                    or @_ == 2 and $entry->has_attribute($key)   # Just a key
            }
        }
    }

    return @matches;
}

sub old_add {
    my ($self, $user, $amount, $description, $data) = @_;

    Carp::carp("Plugin uses deprecated old-style call to \$cart->add");

    $data->{COMPATIBILITY} = 1;

    my $entry = RevBank::Cart::Entry->new(
        defined $user ? 0 : $amount,
        $description,
        $data
    );
    $entry->add_contra($user, $amount, $description) if defined $user;
    $entry->{FORCE} = 1;

    return $self->add_entry($entry);
}

1;
