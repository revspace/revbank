use v5.32;
use warnings;
use experimental qw(signatures);

use Test2::V0;
no warnings qw(experimental);

use File::Temp ();
use File::Basename qw(basename);

use RevBank::Plugins;
use RevBank::Shell;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINS} = "adduser";
$ENV{REVBANK_PLUGINDIR} = "./plugins";
RevBank::Plugins::load;

my $aborted;
my $rejected;

package Adduser::Test {
	use parent 'RevBank::Plugin';

	RevBank::Plugins::register __PACKAGE__;

	sub id { 'fake_plugin' }
	sub hook_abort { $aborted = 1 }
	sub hook_reject { $rejected = 1 }
};

open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

sub exec_ok($cmd) {
	$rejected = 0;
	$aborted = 0;
	ex $cmd;
	ok !$rejected, ">$cmd< did not reject";
	ok !$aborted,  ">$cmd< did not abort";
}

sub aborts_ok($cmd) {
	$aborted = 0;
	ex $cmd;
	ok $aborted,  ">$cmd< aborted";
}

is balance("aap"), undef;
exec_ok "adduser aap";
ok balance("aap") == 0;

aborts_ok "adduser aap";      # exists
aborts_ok "adduser 42";       # numeric
aborts_ok "adduser aap!";     # invalid
aborts_ok "adduser -aap";     # invalid
aborts_ok "adduser +aap";     # invalid
aborts_ok "adduser *aap";     # invalid
aborts_ok "adduser 'a b'";    # invalid
aborts_ok "adduser adduser";  # known command

is balance("noot"), undef;
exec_ok "adduser noot";
ok balance("noot") == 0;

like dies { RevBank::Accounts::delete("*bla") }, qr/not supported/;
like dies { RevBank::Accounts::delete("+bla") }, qr/not supported/;
like dies { RevBank::Accounts::delete("-bla") }, qr/not supported/;
like dies { RevBank::Accounts::delete("bla") },  qr/No such/;
is RevBank::Accounts::delete("AAP"), "aap";
is balance("aap"), undef;
RevBank::Accounts::update("noot", RevBank::Amount->new(4200), -999);
ok balance("noot") == 42;
like dies { RevBank::Accounts::delete("noot") },  qr/balance/;
ok balance("noot") == 42;

done_testing;
