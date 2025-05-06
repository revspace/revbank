package RevBank::Plugins;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since v5.36

use FindBin qw($RealBin);

use RevBank::Eval;
use RevBank::Plugin;
use RevBank::Global;

use Carp qw(croak);
use Exporter;
our @EXPORT = qw(call_hooks);

$ENV{REVBANK_PLUGINDIR} ||= "$RealBin/plugins";

my @plugins;

sub _read_file($fn) {
    $fn =~ s[^~/][$ENV{HOME}/];
    if ($fn =~ m[/]) {
        $fn =~ s[^][$ENV{REVBANK_DATADIR}/] if $fn !~ m[^/];
    } else {
        $fn =~ s[^][$ENV{REVBANK_PLUGINDIR}/];
    }

    open my $fh, '<', $fn or die "Can't read $fn: $!\n";
    local $/;
    my $code = readline $fh;
    close $fh;
    return $code;
}

sub call_hooks {
    my $hook = shift;
    my $method = "hook_$hook";
    my $success = 1;

    for my $class (@plugins) {
         if ($class->can($method)) {
            my ($rv, @message) = eval { $class->$method(@_) };

            if ($@) {
                $success = 0;
                call_hooks("plugin_fail", $class->id, "$class->$method died: $@");
            } elsif (defined $rv and ref $rv) {
                main::abort(@message) if $rv == ABORT;

                $success = 0;
                call_hooks("plugin_fail", $class->id, "$class->$method returned an unsupported value");
            }
        }
    }

    return $success;
};

sub register(@new_plugins) {
    call_hooks("register", $_) for @new_plugins;
    push @plugins, @new_plugins;
}

sub load() {
    my @config = $ENV{REVBANK_PLUGINS} || slurp("plugins");
    chomp @config;
    s/#.*//g for @config;
    @config = map /(\S+)/g, grep /\S/, @config;

    for my $fn (@config) {
        my $name = $fn =~ s[.*/][]r;
        my $package = "RevBank::Plugin::$name";

        if (grep $_ eq $package, @plugins) {
            warn "Plugin '$name' is defined more than once; only the first is used.\n";
            next;
        }

        my $code = eval { _read_file $fn } or do {
            warn $@ || "$fn contains no code.\n", "Skipping plugin $fn.\n";
            next;
        };

        RevBank::Eval::clean_eval(qq[
            use strict;
            use warnings;
            use v5.32;
            use experimental 'signatures';
            use experimental 'isa';
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
        ] . "\n#line 1 $fn\n$code");

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
