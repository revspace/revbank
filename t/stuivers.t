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

$ENV{REVBANK_PLUGINS} = "adduser cash deposit deposit_methods withdraw products users stuivers";
$ENV{REVBANK_PLUGINDIR} = "./plugins";

RevBank::FileIO::spurt "log" => "";  # failed command => account name invokes log

RevBank::FileIO::spurt "products" => <<'END';
p00 0.00 "Testproduct"
p01 0.01 "Testproduct"
p02 0.02 "Testproduct"
p03 0.03 "Testproduct"
p04 0.04 "Testproduct"
p05 0.05 "Testproduct"
p06 0.06 "Testproduct"
p07 0.07 "Testproduct"
p08 0.08 "Testproduct"
p09 0.09 "Testproduct"
p10 0.10 "Testproduct"
END

RevBank::Plugins::load;
open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

is balance("aap"), undef;
ex "adduser aap";

# deposit truncates
ex "deposit 0.00 cash; aap"; is balance("aap")->cents,  0;
ex "deposit 0.01 cash; aap"; is balance("aap")->cents,  0;
ex "deposit 0.02 cash; aap"; is balance("aap")->cents,  0;
ex "deposit 0.03 cash; aap"; is balance("aap")->cents,  0;
ex "deposit 0.04 cash; aap"; is balance("aap")->cents,  0;
ex "deposit 0.05 cash; aap"; is balance("aap")->cents,  5;
ex "deposit 0.06 cash; aap"; is balance("aap")->cents, 10;
ex "deposit 0.07 cash; aap"; is balance("aap")->cents, 15;
ex "deposit 0.08 cash; aap"; is balance("aap")->cents, 20;
ex "deposit 0.09 cash; aap"; is balance("aap")->cents, 25;
ex "deposit 0.10 cash; aap"; is balance("aap")->cents, 35;
                             is balance("-cash")->cents, -35;

# withdraw rounds
ex "withdraw 0.00; aap"; is balance("aap")->cents,  35;
ex "withdraw 0.01; aap"; is balance("aap")->cents,  35;
ex "withdraw 0.02; aap"; is balance("aap")->cents,  35;
ex "withdraw 0.03; aap"; is balance("aap")->cents,  30;
ex "withdraw 0.04; aap"; is balance("aap")->cents,  25;
ex "withdraw 0.05; aap"; is balance("aap")->cents,  20;
ex "withdraw 0.06; aap"; is balance("aap")->cents,  15;
ex "withdraw 0.07; aap"; is balance("aap")->cents,  10;
ex "withdraw 0.08; aap"; is balance("aap")->cents,   0;
ex "withdraw 0.09; aap"; is balance("aap")->cents, -10;
ex "withdraw 0.10; aap"; is balance("aap")->cents, -20;
                         is balance("-cash")->cents, 20;

# payments round on contra acount
ex "p00; cash"; is balance("-cash")->cents,  20;
ex "p01; cash"; is balance("-cash")->cents,  20; is balance("-cash/rounding")->cents, -1;
ex "p02; cash"; is balance("-cash")->cents,  20; is balance("-cash/rounding")->cents, -3;
ex "p03; cash"; is balance("-cash")->cents,  15; is balance("-cash/rounding")->cents, -1;
ex "p04; cash"; is balance("-cash")->cents,  10; is balance("-cash/rounding")->cents,  0;
ex "p05; cash"; is balance("-cash")->cents,   5; is balance("-cash/rounding")->cents,  0;
ex "p06; cash"; is balance("-cash")->cents,   0; is balance("-cash/rounding")->cents, -1;
ex "p07; cash"; is balance("-cash")->cents,  -5; is balance("-cash/rounding")->cents, -3;
ex "p08; cash"; is balance("-cash")->cents, -15; is balance("-cash/rounding")->cents, -1;
ex "p09; cash"; is balance("-cash")->cents, -25; is balance("-cash/rounding")->cents,  0;
ex "p10; cash"; is balance("-cash")->cents, -35; is balance("-cash/rounding")->cents,  0;

done_testing;
