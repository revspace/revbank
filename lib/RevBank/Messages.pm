package RevBank::Messages;
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

sub hook_plugin_fail {
    my ($class, $plugin, $error) = @_;
    warn "Plugin '$plugin' failed: $error\n";
}

sub hook_cart_changed {
    my ($class, $cart) = @_;
    $cart->size or return;
    say "Pending:";
    $cart->display;

    if (not $cart->entries('refuse_checkout')) {
        my $sum = $cart->sum;
        my $what = $sum > 0 ? "add" : "pay";
        my $abs = $sum->abs;
        say "Enter username to $what $abs; type 'abort' to abort.";
    }
}

sub hook_abort {
    my ($class, $cart) = @_;
    say "\e[1;4mABORTING TRANSACTION.\e[0m";
}

sub hook_invalid_input {
    my ($class, $cart, $word) = @_;
    say "$word: No such product, user, or command.";
}

sub hook_reject {
    my ($class, $plugin, $reason, $abort) = @_;
    say $abort ? $reason : "$reason Enter 'abort' to abort.";
}

sub hook_user_balance {
    my ($class, $username, $old, $delta, $new) = @_;
    my $sign = $delta >= 0 ? '+' : '-';
    my $rood = $new < 0 ? '31;' : '';
    my $abs = abs($delta);
    my $warn = $new < -13.37 ? " \e[5;1m(!!)\e[0m" : "";
    $_ = $_->string("+") for $old, $new;
    printf "New balance for $username: $old $sign $abs = \e[${rood}1m$new\e[0m$warn\n",
}

sub hook_user_created {
    my ($class, $username) = @_;
    say "New account '$username' created.";
}

1;
