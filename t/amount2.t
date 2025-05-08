# These tests are generated using ChatGPT.
# The tests that ChatGPT got wrong, or that throw (intended) warnings, are commented out.

use strict;
use warnings;
use Test2::Require::Perl 'v5.34';  # Test2::Compare runs into the isa/->isa bug
use Test2::V0;

use RevBank::Amount;

my $a = RevBank::Amount->new(500);
my $b = RevBank::Amount->new(200);
my $c = RevBank::Amount->new(-100);

# Test basic arithmetic operations
is($a + $b, RevBank::Amount->new(700), "Addition");
is($a - $b, RevBank::Amount->new(300), "Subtraction");
is($a * 2, RevBank::Amount->new(1000), "Multiplication");
#is($a / 2, RevBank::Amount->new(250), "Division"); # Throws a warning (intended)
is($c * -1, RevBank::Amount->new(100), "Unary minus");

# Test comparison operators
ok($a > $b, "Greater than");
ok($c < $b, "Less than");
ok($a == RevBank::Amount->new(500), "Equality");

# Test stringification
is($a->string, "5.00", "Stringification");
is($a->string_flipped, "+ 5.00", "Stringification with flipped sign");

# Test parsing from string
is(RevBank::Amount->parse_string("5"), $a, "Parsing from string");

# Test floating point arithmetic
my $d = RevBank::Amount->new_from_float(4.56);
is($d->float, 4.56, "Conversion to floating point");
# ChatGPT got this wrong:
#is($d * 2.5, RevBank::Amount->new(11.4), "Multiplication with float");
is($d * 2.5, RevBank::Amount->new(1140), "Multiplication with float");

# ChatGPT got this wrong:
#is($d / 2, RevBank::Amount->new(2.28), "Division with float");
# But the correct one throws a warning (as intended):
#is($d / 2, RevBank::Amount->new(228), "Division with float");


# Test constructor with floating point input
is(RevBank::Amount->new_from_float(123.456), RevBank::Amount->new(12346), "Float constructor");

# Test constructor with rounding to nearest integer
is(RevBank::Amount->new_from_float(123.495), RevBank::Amount->new(12350), "Float constructor with rounding");

# These make no sense:
### Test constructor with rounding down
##is(RevBank::Amount->new_from_float(123.449), RevBank::Amount->new(12344), "Float constructor with rounding down");
##
### Test constructor with rounding up
##is(RevBank::Amount->new_from_float(123.455), RevBank::Amount->new(12346), "Float constructor with rounding up");

# Test parsing of various input formats
is(RevBank::Amount->parse_string("+1234"), RevBank::Amount->new(123400), "Parse positive integer");
is(RevBank::Amount->parse_string("-1234"), RevBank::Amount->new(-123400), "Parse negative integer");
is(RevBank::Amount->parse_string("1.23"), RevBank::Amount->new(123), "Parse positive float");
is(RevBank::Amount->parse_string("-1.23"), RevBank::Amount->new(-123), "Parse negative float");
is(RevBank::Amount->parse_string("-1.234"), undef, "Parse invalid float");

# Test overloading of comparison operators
ok(RevBank::Amount->new(100) > RevBank::Amount->new(50), "Overloaded greater than");
ok(RevBank::Amount->new(50) < RevBank::Amount->new(100), "Overloaded less than");
ok(RevBank::Amount->new(50) == RevBank::Amount->new(50), "Overloaded equal");


my $C = "RevBank::Amount";

subtest 'string parsing' => sub {

    # valid input tests

    is($C->parse_string("0"),         $C->new(0),     'parsing zero');
    is($C->parse_string("0.0"),       $C->new(0),     'parsing zero with decimal point');
    is($C->parse_string("100"),       $C->new(10000), 'parsing integer value');
    is($C->parse_string("-100"),      $C->new(-10000), 'parsing negative integer value');
    is($C->parse_string("100.00"),    $C->new(10000), 'parsing integer value with decimal point');
    is($C->parse_string("100.25"),    $C->new(10025), 'parsing decimal value with two decimal places');
    is($C->parse_string("100.2"),     $C->new(10020), 'parsing decimal value with one decimal place');
    #is($C->parse_string("100.257"),   $C->new(10026), 'parsing decimal value with three decimal places (rounded up)');  # is not valid input
    #is($C->parse_string("100.254"),   $C->new(10025), 'parsing decimal value with three decimal places (rounded down)');  # is not valid input
    is($C->parse_string("+100.25"),   $C->new(10025), 'parsing positive decimal value with sign');
    is($C->parse_string("-100.25"),   $C->new(-10025), 'parsing negative decimal value with sign');
    is($C->parse_string("  100.25  "), $C->new(10025), 'parsing decimal value with leading and trailing whitespace');
    is($C->parse_string("4.2"),       $C->new(420),   'parsing decimal value with one decimal place (no trailing zero)');

    # invalid input tests

    is($C->parse_string(""),             undef,         'empty input');
    is($C->parse_string("   "),          undef,         'whitespace only');
    is($C->parse_string("."),            undef,         'single decimal point');
    is($C->parse_string("-"),            undef,         'single hyphen');
    is($C->parse_string("+"),            undef,         'single plus sign');
    is($C->parse_string("-100.256"),     undef,         'value with too many decimal places');
    is($C->parse_string("-100.2567"),    undef,         'value with too many decimal places');
    is($C->parse_string("foo"),          undef,         'non-numeric input');
    is($C->parse_string("100foo"),       undef,         'non-numeric input after numeric value');
    #is($C->parse_string("100,00"),       undef,         'comma as decimal separator');  # is valid input
    is($C->parse_string("100.00.00"),    undef,         'multiple decimal points');
    is($C->parse_string("-100.2.5"),     undef,         'multiple decimal points');
};

subtest 'parse_string' => sub {
    my @invalid = qw(foobar -1.2.3 +1.2.3 123.1234 123.123456);
    for my $input (@invalid) {
        is(RevBank::Amount->parse_string($input), undef, "invalid input '$input' returns undef");
    }
};

done_testing();
