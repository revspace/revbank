use v5.32;

use Test2::V0;

use RevBank::Global;

# Invalid syntax
is parse_amount(undef), undef;
is parse_amount(""), undef;
is parse_amount("0.123"), undef;
is parse_amount("42.000"), undef;
is parse_amount("a"), undef;
is parse_amount("(1+1)"), undef;
is parse_amount("+"), undef;
is parse_amount("-"), undef;
is parse_amount("++"), undef;
is parse_amount("--"), undef;
is parse_amount("+-"), undef;
is parse_amount("-+"), undef;
is parse_amount("1+"), undef;
is parse_amount("1-"), undef;
is parse_amount("1 1"), undef;

# Out of range
ok dies { parse_amount("-1") };
ok dies { parse_amount("0-42") };
ok dies { parse_amount("999999") };

# Bare number
is parse_amount("42")->cents, 4200;
is parse_amount("42.0")->cents, 4200;
is parse_amount("42.00")->cents, 4200;


# Arithmetic
is parse_amount("1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1")->cents, 4200;

is parse_amount("-42+42")->cents, 0;
is parse_amount("+42")->cents, 4200;
is parse_amount("--42")->cents, 4200;
is parse_amount("+42-42")->cents, 0;
is parse_amount("0--42")->cents, 4200;
is parse_amount("0++42")->cents, 4200;
is parse_amount("42+-42")->cents, 0;
is parse_amount("42-+42")->cents, 0;
is parse_amount("0+42")->cents, 4200;
is parse_amount("42-42")->cents, 0;

is parse_amount(" - 42 + 42")->cents, 0;
is parse_amount(" + 42 ")->cents, 4200;
is parse_amount(" - - 42 ")->cents, 4200;
is parse_amount(" + 42 - 42 ")->cents, 0;
is parse_amount(" 0 - - 42 ")->cents, 4200;
is parse_amount(" 0 + + 42 ")->cents, 4200;
is parse_amount(" 42 + - 42 ")->cents, 0;
is parse_amount(" 42 - + 42 ")->cents, 0;
is parse_amount(" 0  + 42 ")->cents, 4200;
is parse_amount(" 42 - 42 ")->cents, 0;

is parse_amount("-4.20+4.20")->cents, 0;
is parse_amount("+4.20")->cents, 420;
is parse_amount("--4.20")->cents, 420;
is parse_amount("+4.20-4.20")->cents, 0;
is parse_amount("0--4.20")->cents, 420;
is parse_amount("0++4.20")->cents, 420;
is parse_amount("4.20+-4.20")->cents, 0;
is parse_amount("4.20-+4.20")->cents, 0;
is parse_amount("0+4.20")->cents, 420;
is parse_amount("4.20-4.20")->cents, 0;

done_testing;
