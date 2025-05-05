use v5.32;
use Test::More;
use File::Temp ();
use File::Basename qw(basename);

use RevBank::Plugins;
use RevBank::Shell;
use RevBank::Products;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINS} = "adduser deposit products users";
$ENV{REVBANK_PLUGINDIR} = "./plugins";
RevBank::Plugins::load;
RevBank::FileIO::spurt "products", <<'END';
foo       1.00          "product 1"
bar       2.00          "product 2" +a
"foo bar" 3.00          "product with space in id"
baz       4.20          "product 4" +b +c +dd
xyzzy     5.00          "product 5" +bb +cc +dd +ee +s
a         0.10          "fee 1"
b         0.20          "fee 2" +a
c         0.30@+contra1 "different contra 1"
+aa       0.10          "fee 3"
+bb       0.20          "fee 4" +aa
+cc       0.30@+contra1 "different contra 2"
+dd       -50%          "discount"
+ee       -10%@+contra1 "discount on contra1"
s         0.01          "opaque test" #OPAQUE

kwartje   0.25@mies     "contra is normal user"
tagstest  0.00          "tags test" #tag1 #tag2=b #tag3=c "#tag4=has spaces"
END

open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

is balance("aap"), undef;
ex "adduser aap";
ex "deposit 100; aap"; $b = 10000;
is balance("aap")->cents, $b;
ex "foo; aap"; $b -= 100;
is balance("aap")->cents, $b;
ex "foo aap"; $b -= 100;
is balance("aap")->cents, $b;
ex "bar aap"; $b -= 210;
is balance("aap")->cents, $b;
ex "foo\\ bar aap"; $b -= 300;
is balance("aap")->cents, $b;
ex "'foo bar' aap"; $b -= 300;
is balance("aap")->cents, $b;

is balance("+sales/products")->cents, 10000 - $b;

ex "baz aap"; $b -= (
	.5 * (  # discount dd
		420 + 20 + 10  # baz + b + a
	)
	+ 30 # c
);
is balance("aap")->cents, $b;
is balance("+sales/products")->cents, 10000 - ($b + 30);
is balance("+contra1")->cents, 30;

ex "xyzzy aap"; $b -= (
	.5 * (  # discount dd
		500 + 20 + 10  # xyzzy + bb + aa
	)
	+ .9 * (  # discount cc
		30  # ee
	)
	+ 1
);
is balance("aap")->cents, $b;
is balance("+sales/products")->cents, 10000 - ($b + 30 + .9 * 30);
is balance("+contra1")->cents, 30 + .9 * 30;

ex "adduser noot; deposit 10; noot";
ex "adduser mies";
ex "kwartje noot";
is balance("noot")->cents, 975;
is balance("mies")->cents, 25;

my $p = RevBank::Products::read_products;

is_deeply
	$p->{"tagstest"}{tags},
	{ tag1 => 1, tag2 => "b", tag3 => "c", tag4 => "has spaces" };

is $p->{"xyzzy"}{price}->cents,       500;  # without addons
is $p->{"xyzzy"}{total_price}->cents, 293;  # with addons
is $p->{"xyzzy"}{hidden_fees}->cents,   1;  # opaque addons
is $p->{"xyzzy"}{tag_price}->cents,   292;  # with addons except opaque

done_testing;
