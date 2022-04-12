package RevBank::Messages;

use v5.28;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use RevBank::Global;
use base 'RevBank::Plugin';

# Don't edit this file just to change the messages. Instead, RTFM and define
# your own hooks.

BEGIN {
    RevBank::Plugins::register("RevBank::Messages");
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
        my $what = $sum->cents > 0 ? "add" : "pay";
        my $abs  = $sum->abs;
        say "Enter username to $what $abs; type 'abort' to abort.";
    }
}

sub hook_abort($class, $cart, @) {
    say "\e[1;4mABORTING TRANSACTION.\e[0m";
}

sub hook_invalid_input($class, $cart, $word, @) {
    say "$word: No such product, user, or command.";
}

sub hook_reject($class, $plugin, $reason, $abort, @) {
    say $abort ? $reason : "$reason Enter 'abort' to abort.";
}

sub hook_user_balance($class, $username, $old, $delta, $new, @) {
    my $sign = $delta->cents >= 0 ? '+' : '-';
    my $rood = $new->cents < 0 ? '31;' : '';
    my $abs  = $delta->abs;
    my $warn = $new->cents < -1984 ? " \e[5;1m(!!)\e[0m" : "";

    $_ = $_->string("+") for $old, $new;
    printf "New balance for $username: $old $sign $abs = \e[${rood}1m$new\e[0m$warn\n",
}

sub hook_user_created($class, $username, @) {
    say "New account '$username' created.";
}

1;
