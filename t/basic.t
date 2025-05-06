use v5.32;
use Test::More;
use File::Temp ();
use File::Basename qw(basename);

use RevBank::Global;
use RevBank::Plugins;
use RevBank::Shell;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINS} = "unlisted undo users";
$ENV{REVBANK_PLUGINDIR} = "./plugins";
RevBank::Plugins::load;

spurt "nextid", "000";
spurt "accounts", "aap 10.00";  # no newline, to test automatic fixing

open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

# transaction 000
is balance("aap")->cents, 1000;
is slurp("accounts"), "aap 10.00\n", "using accounts file fixes missing newline";
ex "unlisted 2 test; aap";
is balance("aap")->cents, 800;
is balance("+sales/unlisted")->cents, 200;
is slurp("nextid"), "001";

# transaction 001
ex "undo 000";
is slurp("nextid"), "002";
is balance("aap")->cents, 1000;
is balance("+sales/unlisted")->cents, 0;

# failed transaction
ex "undo 000";  # can't undo twice
is slurp("nextid"), "002";
is balance("aap")->cents, 1000;
is balance("+sales/unlisted")->cents, 0;

# failed transaction
ex "undo 001";  # can't undo undo
is slurp("nextid"), "002";
is balance("aap")->cents, 1000;
is balance("+sales/unlisted")->cents, 0;

done_testing;
