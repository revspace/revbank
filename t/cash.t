use v5.32;
use Test::More;
use File::Temp ();
use File::Basename qw(basename);

use RevBank::Plugins;
use RevBank::Shell;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINS} = "adduser cash deposit deposit_methods withdraw skim users";
$ENV{REVBANK_PLUGINDIR} = "./plugins";
RevBank::Plugins::load;
open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

is balance("aap"), undef;
ex "adduser aap";
ex "deposit 10 cash; aap";
is balance("aap")->cents, 1000;
is balance("-cash")->cents, -1000;
ex "withdraw 5; aap";
is balance("aap")->cents, 500;
is balance("-cash")->cents, -500;
ex "cash 5";
ex "cash 6 'fix pls'";
is balance("-cash")->cents, -600;
is balance("-expenses/discrepancies")->cents, 100;
ex "cash 4 'fix pls'";
is balance("-cash")->cents, -400;
is balance("-expenses/discrepancies")->cents, -100;

ex "skim 3; aap";
is balance("aap")->cents, 500;  # unchanged
is balance("-cash")->cents, -100;
is balance("-cash/skimmed")->cents, -300;

ex "unskim 0.50; aap";
is balance("aap")->cents, 500;  # unchanged
is balance("-cash")->cents, -150;
is balance("-cash/skimmed")->cents, -250;

done_testing;
