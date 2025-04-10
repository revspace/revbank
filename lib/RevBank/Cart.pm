package RevBank::Cart;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since v5.36

use Carp ();
use List::Util ();
use RevBank::Global;
use RevBank::Accounts;
use RevBank::FileIO;
use RevBank::Cart::Entry;

{
    package RevBank::Cart::CheckoutProhibited;
    sub new($class, $reason) { return bless \$reason, $class; }
    sub reason($self) { return $$self; }
}

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
    ref $data or Carp::croak "Non-hash data argument";

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

sub prohibit_checkout($self, $bool, $reason) {
    if ($bool) {
        $self->{prohibited} = $reason;
    } else {
        delete $self->{prohibited};
    }
}

sub deltas($self, $account) {
    my %deltas = ($account => RevBank::Amount->new(0));

    for my $entry (@{ $self->{entries} }) {
        $deltas{$_->{account}} += $_->{amount} * $entry->quantity
            for $entry, $entry->contras;
    }

    return \%deltas;
}


sub checkout($self, $account) {
    if ($self->{prohibited}) {
        die RevBank::Cart::CheckoutProhibited->new(
            "Cannot complete transaction: $self->{prohibited}"
        );
    }

    if ($self->entries('refuse_checkout')) {
        $self->display;
        die "Refusing to finalize deficient transaction";
    }

    $account = RevBank::Accounts::assert_account($account);

    my $entries = $self->{entries};

    for my $entry (@$entries) {
        $entry->sanity_check;
        $entry->account($account);
    }

    RevBank::FileIO::with_lock {
        my $fn = ".revbank.nextid";
        my $transaction_id = eval { RevBank::FileIO::slurp($fn) };
        my $legacy_id = 0;

        if (defined $transaction_id) {
            chomp $transaction_id;
            if ($transaction_id eq "LEGACY") {
                $legacy_id = 1;
                $transaction_id = time() - 1300000000;;
            }
        } else {
            warn "Could not read $fn; using timestamp as first transaction ID.\n";
            $transaction_id = time() - 1300000000;
        }

        RevBank::Plugins::call_hooks("checkout_prepare", $self, $account, $transaction_id)
            or die "Refusing to finalize after failed checkout_prepare";

        for my $entry (@$entries) {
            $entry->sanity_check;
            $entry->account($account) if not $entry->account;
        }

        RevBank::FileIO::spurt($fn, ++(my $next_id = $transaction_id)) unless $legacy_id;

        RevBank::Plugins::call_hooks("checkout", $self, $account, $transaction_id);

        my $deltas = $self->deltas($account);

        for my $account (reverse sort keys %$deltas) {
            # The reverse sort is a lazy way to make the "-" accounts come last,
            # which looks nicer with the "cash" plugin.
            RevBank::Accounts::update($account, $deltas->{$account}, $transaction_id)
                if $deltas->{$account} != 0;
        }

        RevBank::Plugins::call_hooks("checkout_done", $self, $account, $transaction_id);

        sleep 1;  # look busy

        $self->empty;
    };
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
