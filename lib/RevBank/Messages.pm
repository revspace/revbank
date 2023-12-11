package RevBank::Messages;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since v5.36

use RevBank::Global;
use base 'RevBank::Plugin';

# Don't edit this file just to change the messages. Instead, RTFM and define
# your own hooks.

BEGIN {
    RevBank::Plugins::register("RevBank::Messages");
    *hidden = \&RevBank::Users::is_hidden;
}


sub command { return NEXT; }
sub id { 'built in messages' }

sub hook_startup {
    say "\e[0m\n\n\nWelcome to the RevBank Shell, version $::VERSION\n";
}

sub hook_plugin_fail($class, $plugin, $error, @) {
    warn "Plugin '$plugin' failed: $error\n";
}

sub hook_cart_changed($class, $cart, @) {
    $cart->size or return;
    say "Pending:";
    $cart->display;

    if (not $cart->entries('refuse_checkout')) {
        my $sum  = $cart->sum;
        my $what = $sum->cents > 0 ? "add" : $cart->entries('is_withdrawal') ? "deduct" : "pay";
        my $dir  = $sum->cents > 0 ? "to" : "from";
        my $abs  = $sum->abs;
        say "Enter username to $what $abs $dir your account; type 'abort' to abort.";
    }
}

sub hook_abort($class, $cart, @) {
    say "\e[1;4mABORTING TRANSACTION.\e[0m";
}

sub hook_invalid_input($class, $cart, $origword, $lastword, $allwords, @) {
    say "$origword: No such product, user, or command.";
    my @other = splice @$allwords, 1;
    if (@other) {
        $other[-1] =~ s/^/ and / if @other > 1;
        say "(Also tried as " . join(@other > 2 ? ", " : "", @other) . ".)";
    }
}

sub hook_reject($class, $plugin, $reason, $abort, @) {
    say $abort ? $reason : "$reason Enter 'abort' to abort.";
}

sub hook_user_balance($class, $username, $old, $delta, $new, @) {
    return if hidden $username and not $ENV{REVBANK_DEBUG};

    my $sign = $delta->cents >= 0 ? '+' : '-';
    my $rood = $new->cents < 0 ? '31;' : '';
    my $abs  = $delta->abs;
    my $warn = $new->cents < -2200 ? " \e[5;1m(!!)\e[0m" : "";

    $_ = $_->string("+") for $old, $new;
    printf "New balance for $username: $old $sign $abs = \e[${rood}1m$new\e[0m$warn\n",
}

sub hook_user_created($class, $username, @) {
    return if hidden $username and not $ENV{REVBANK_DEBUG};

    say "New account '$username' created.";
}

1;
