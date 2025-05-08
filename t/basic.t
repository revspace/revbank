use v5.32;
use experimental qw(signatures);

use Test2::V0;
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

close STDOUT;
open STDOUT, ">", \my $output or die $!;

sub ex($line) {
	$output = "";
	RevBank::Shell::exec($line);
	$output =~ s/\e\[[^A-Za-z]+[A-Za-z]//g;  # remove ansi colors
}

BEGIN {
	*balance = \&RevBank::Accounts::balance;
}

# transaction 000
is balance("aap")->cents, 1000;
is slurp("accounts"), "aap 10.00\n", "using accounts file fixes missing newline";
ex "unlisted 2 'TEST DESCRIPTION'; aap";
like   $output, qr/\b000\b/, "prints transaction id";
unlike $output, qr/001/, "does not print next id";
unlike $output, qr/pending/, "does not print next id";
like   $output, qr/\b2.00\b/, "prints price";
like   $output, qr/\bTEST DESCRIPTION\b/, "prints description";
like   $output, qr/\b8.00\b/, "prints new balance";
like   $output, qr/\baap\b/, "prints user account name";
is balance("aap")->cents, 800;
is balance("+sales/unlisted")->cents, 200;
is slurp("nextid"), "001";

# transaction 001
ex "undo 000";
like   $output, qr/\b000\b/, "prints previous id";
like   $output, qr/\b001\b/, "prints transaction id";
unlike $output, qr/002/, "does not print next id";
unlike $output, qr/-undo/, "does not print internal undo account name";
like   $output, qr/\b10.00\b/, "prints new balance";
like   $output, qr/\baap\b/, "prints user account name";
is slurp("nextid"), "002";
is balance("aap")->cents, 1000;
is balance("+sales/unlisted")->cents, 0;

# failed transaction
ex "undo 000";  # can't undo twice
unlike $output, qr/002/, "does not print next id";
is slurp("nextid"), "002";
is balance("aap")->cents, 1000;
is balance("+sales/unlisted")->cents, 0;

# failed transaction
ex "undo 001";  # can't undo undo
unlike $output, qr/002/, "does not print next id";
is slurp("nextid"), "002";
is balance("aap")->cents, 1000;
is balance("+sales/unlisted")->cents, 0;

done_testing;
