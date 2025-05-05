use Test::More;
use File::Temp ();
use File::Basename qw(basename);

use RevBank::Plugins;
use RevBank::Shell;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINDIR} = "./plugins";
RevBank::Plugins::load;
open STDOUT, ">", "/dev/null";

is(RevBank::Accounts::balance("aap"), undef);
is(RevBank::Accounts::balance("noot"), undef);
RevBank::Shell::exec(split " ", "adduser aap");
RevBank::Shell::exec(split " ", "adduser noot");
RevBank::Shell::exec(split " ", "deposit 10 \0SEPARATOR aap");
RevBank::Shell::exec(split " ", "deposit 20 \0SEPARATOR noot");
is(RevBank::Accounts::balance("aap")->cents, 1000);
is(RevBank::Accounts::balance("noot")->cents, 2000);
RevBank::Shell::exec(split " ", "give aap 1 test \0SEPARATOR noot");
is(RevBank::Accounts::balance("aap")->cents, 1100);
is(RevBank::Accounts::balance("noot")->cents, 1900);
RevBank::Shell::exec(split " ", "take aap 2 test \0SEPARATOR noot");
is(RevBank::Accounts::balance("aap")->cents, 900);
is(RevBank::Accounts::balance("noot")->cents, 2100);
RevBank::Shell::exec(split " ", "adduser mies");
RevBank::Shell::exec(split " ", "take aap noot mies 9.03 test \0SEPARATOR mies");
is(RevBank::Accounts::balance("aap")->cents, 599);
is(RevBank::Accounts::balance("noot")->cents, 1799);
is(RevBank::Accounts::balance("mies")->cents, 602);

done_testing;
