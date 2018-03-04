package RevBank::Plugins;
use strict;
use RevBank::Eval;
use RevBank::Plugin;
use RevBank::Global;
use Exporter;
our @EXPORT = qw(call_hooks load_plugins);

my @plugins;

sub _read_file {
    local (@ARGV) = @_;
    readline *ARGV;
}

sub call_hooks {
    my $hook = shift;
    my $method = "hook_$hook";
    for my $class (@plugins) {
         if ($class->can($method)) {
            my ($rv, $message) = $class->$method(@_);

            if (defined $rv and ref $rv) {
                main::abort($message) if $rv == ABORT;
                warn "$class->$method returned an unsupported value.\n";
            }
        }
    }
};

sub register {
    call_hooks("register", $_) for @_;
    push @plugins, @_;
}

sub load {
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
            package $package;
            BEGIN { RevBank::Global->import; }
            our \@ISA = qw(RevBank::Plugin);
            our \%ATTR;
            sub MODIFY_CODE_ATTRIBUTES {
                my (\$class, \$sub, \@attrs) = \@_;
                \$ATTR{ \$sub } = "\@attrs";
                return;
            }
            sub FETCH_CODE_ATTRIBUTES {
                return \$ATTR{ +pop };
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

sub new {
    return map $_->new, @plugins;
}

1;
