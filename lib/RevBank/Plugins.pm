package RevBank::Plugins;

use v5.28;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use RevBank::Eval;
use RevBank::Plugin;
use RevBank::Global;
use Exporter;
our @EXPORT = qw(call_hooks load_plugins);

my @plugins;

sub _read_file($fn) {
    local @ARGV = ($fn);
    readline *ARGV;
}

sub call_hooks($hook, @args) {
    my $method = "hook_$hook";
    for my $class (@plugins) {
         if ($class->can($method)) {
            my ($rv, @message) = $class->$method(@args);

            if (defined $rv and ref $rv) {
                main::abort(@message) if $rv == ABORT;
                warn "$class->$method returned an unsupported value.\n";
            }
        }
    }
};

sub register(@new_plugins) {
    call_hooks("register", $_) for @new_plugins;
    push @plugins, @new_plugins;
}

sub load($class) {
    my @config = _read_file('revbank.plugins');
    chomp @config;
    s/#.*//g for @config;
    @config = map /(\S+)/, grep /\S/, @config;

    for my $name (@config) {
        my $fn = "plugins/$name";
        my $package = "RevBank::Plugin::$name";
        if (not -e $fn) {
            warn "$fn does not exist; skipping plugin.\n";
            next;
        }
        RevBank::Eval::clean_eval(qq[
            use strict;
            use warnings;
            use feature qw(signatures state);
            no warnings 'experimental::signatures';
            package $package;
            BEGIN { RevBank::Global->import; }
            our \@ISA = qw(RevBank::Plugin);
            our \%ATTR;
            sub MODIFY_CODE_ATTRIBUTES(\$class, \$sub, \@attrs) {
                \$ATTR{ \$sub } = "\@attrs";
                return;
            }
            sub FETCH_CODE_ATTRIBUTES {
                return \$ATTR{ +pop };
            }
            sub HELP1 {
                \$::HELP1{ +shift } = +pop;
            }
            sub HELP {
                \$::HELP{ +shift } = +pop;
            }
            sub id { '$name' }
        ] . "\n#line 1 $fn\n" . join "", _read_file($fn));

        if ($@) {
            call_hooks("plugin_fail", $name, "Compile error: $@");
            next;
        }
        if (not $package->can("command")) {
            warn "Plugin $name does not have a 'command' method; skipping.\n";
            next;
        }

        register $package;
    }
}

sub new($class) {
    return map $_->new, @plugins;
}

1;
