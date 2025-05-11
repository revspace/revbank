use v5.32;
use warnings;
use experimental qw(signatures);

use Test2::V0;
no warnings qw(experimental);

use File::Temp ();
use File::Basename qw(basename);

use RevBank::Plugins;
use RevBank::Shell;
use RevBank::Products;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $c;

package TestCart {
	use RevBank::Global;
	use parent 'RevBank::Plugin';
	sub id { 'test' }

	sub _c($cart) {
		$c = [];
		for my $entry ($cart->entries) {
			push @$c, [ $entry->attribute('product_id') => $entry->quantity ];
		}
	}

	sub command($self, $cart, $input, @) {
		return NEXT if $input ne 'done';
		_c $cart;
		return ACCEPT;
	}

	sub hook_abort($class, $cart, $reason, @) {
		# All of the ex calls will abort because no checkout is done
		return if "@$reason" =~ /Incomplete/;
		_c $cart;
		push @$c, "@$reason";
	}
}

RevBank::Plugins::register('TestCart');

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINS} = "products repeat";
$ENV{REVBANK_PLUGINDIR} = "./plugins";


RevBank::Plugins::load;
RevBank::FileIO::spurt "products", <<'END';
foo       1.00          "product 1"
END

open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

# repeat should work on the last entry, even if other identical entries exist
ex 'foo; foo x 2; done';  is $c, [[foo => 1], [foo => 2]];
ex 'foo; foo * 2; done';  is $c, [[foo => 1], [foo => 2]];
ex 'foo; foo x2; done';   is $c, [[foo => 1], [foo => 2]];
ex 'foo; foo *2; done';   is $c, [[foo => 1], [foo => 2]];
ex 'foo; 2x foo; done';   is $c, [[foo => 1], [foo => 2]];
ex 'foo; 2* foo; done';   is $c, [[foo => 1], [foo => 2]];

ex 'foo; foo; + 1; done';      is $c, [[foo => 1], [foo => 2]];
ex 'foo; foo; +1; done';       is $c, [[foo => 1], [foo => 2]];
ex 'foo; foo; + 1; + 2; done'; is $c, [[foo => 1], [foo => 4]];
ex 'foo; foo; +1; +2; done';   is $c, [[foo => 1], [foo => 4]];
ex 'foo; foo; +7; -3; done';   is $c, [[foo => 1], [foo => 5]];
ex 'foo; foo; -1; done';       is $c, [[foo => 1]];
ex 'foo; foo; - 1; done';      is $c, [[foo => 1]];
ex 'foo; foo x2; -3; done';    is $c, [[foo => 1]];
ex 'foo; foo x2; - 3; done';   is $c, [[foo => 1]];
ex 'foo; foo x0; done';        is $c, [[foo => 1]];
ex 'foo; foo x 0; done';       is $c, [[foo => 1]];
ex 'foo; 0x foo; done';        like $c, [[foo => 1], qr/Invalid value/];

ex 'foo; foo; x2; x3'; like $c, [[foo => 1], [foo => 2], qr/Stacked repetition/];

done_testing;
