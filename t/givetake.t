use v5.32;
use Test2::V0;
use File::Temp ();
use File::Basename qw(basename);

use RevBank::Plugins;
use RevBank::Shell;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINS} = "adduser deposit give take users";
$ENV{REVBANK_PLUGINDIR} = "./plugins";
RevBank::Plugins::load;
open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

is balance("aap"), undef;
is balance("noot"), undef;
ex "adduser aap";
ex "adduser noot";
ex "deposit 10; aap";
ex "deposit 20; noot";
is balance("aap")->cents, 1000;
is balance("noot")->cents, 2000;
ex "give aap 1 test; noot";
is balance("aap")->cents, 1100;
is balance("noot")->cents, 1900;
ex "take aap 2 test; noot";
is balance("aap")->cents, 900;
is balance("noot")->cents, 2100;
ex "adduser mies";
ex "take aap noot mies 9.03 test; mies";
is balance("aap")->cents, 599;
is balance("noot")->cents, 1799;
is balance("mies")->cents, 602;

done_testing;
