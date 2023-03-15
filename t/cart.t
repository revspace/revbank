# These unit tests are written by ChatGPT. Many are wrong, and thus commented.
# But I guess it doesn't hurt to keep the ones that make some sense.

use strict;
use warnings;
use Test::More;

use_ok('RevBank::Cart');
use_ok('RevBank::Cart::Entry');

sub test_add_entry {
my $cart = RevBank::Cart->new();
my $entry = RevBank::Cart::Entry->new(100, "test");
my $result = $cart->add_entry($entry);
is($result, $entry, "add_entry should return the added entry");
# ChatGPT has trouble with lists vs arrays:
#is_deeply($cart->entries(), [$entry], "add_entry should add the entry to the cart");
is_deeply([$cart->entries()], [$entry], "add_entry should add the entry to the cart");
}

sub test_add {
my $cart = RevBank::Cart->new();
my $entry = $cart->add(100, "test");
isa_ok($entry, 'RevBank::Cart::Entry', "add should return a Cart Entry object");
# Huh? No, that doesn't make sense...
#is($entry->amount(), -100, "add should convert the amount to a negative value");
# This accessor method doesn't exist. Maybe it should, though?
#is($entry->description(), "test", "add should set the description of the entry");
}

sub test_select {
my $cart = RevBank::Cart->new();
my $entry1 = RevBank::Cart::Entry->new(100, "test1");
my $entry2 = RevBank::Cart::Entry->new(200, "test2");
$cart->add_entry($entry1);
$cart->add_entry($entry2);
my $result = $cart->select($entry1);
is($result, $entry1, "select should return the selected entry");
is($cart->selected(), $entry1, "selected should return the selected entry");
$result = $cart->select($entry2);
is($result, $entry2, "select should return the selected entry");
is($cart->selected(), $entry2, "selected should return the selected entry");
}

sub test_delete {
my $cart = RevBank::Cart->new();
my $entry1 = RevBank::Cart::Entry->new(100, "test1");
my $entry2 = RevBank::Cart::Entry->new(200, "test2");
$cart->add_entry($entry1);
$cart->add_entry($entry2);
my $result = $cart->delete($entry1);
is($result, 1, "delete should return the number of entries deleted");
# ChatGPT has trouble with lists vs arrays:
#is_deeply($cart->entries(), [$entry2], "delete should remove the specified entry from the cart");
is_deeply([$cart->entries()], [$entry2], "delete should remove the specified entry from the cart");
$result = $cart->delete($entry2);
is($result, 1, "delete should return the number of entries deleted");
# ChatGPT has trouble with lists vs arrays:
#is_deeply($cart->entries(), [], "delete should remove the specified entry from the cart");
is_deeply([$cart->entries()], [], "delete should remove the specified entry from the cart");
}

sub test_empty {
my $cart = RevBank::Cart->new();
my $entry = RevBank::Cart::Entry->new(100, "test");
$cart->add_entry($entry);
$cart->empty();
# ChatGPT has trouble with lists vs arrays:
#is_deeply($cart->entries(), [], "empty should remove all entries from the cart");
is_deeply([$cart->entries()], [], "empty should remove all entries from the cart");
}

# Lol, no, this is completely wrong :)
#sub test_display {
#    my $cart = RevBank::Cart->new;
#    my $entry1 = RevBank::Cart::Entry->new(-500, "Groceries");
#    my $entry2 = RevBank::Cart::Entry->new(-100, "Coffee");
#    $cart->add_entry($entry1);
#    $cart->add_entry($entry2);
#    my $expected_output = "Groceries (-500)\nCoffee (-100)\n";
#    my $output = capture_stdout { $cart->display() };
#    is($output, $expected_output, "display() method correctly prints entries in cart");
#}

test_add_entry;
test_add;
test_select;
test_delete;
test_empty;
#test_display;

done_testing();
