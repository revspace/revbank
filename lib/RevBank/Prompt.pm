package RevBank::Prompt;

use v5.32;
use warnings;
use feature qw(signatures isa);
no warnings "experimental::signatures";

use IO::Select;
use List::Util qw(uniq);
use Term::ReadLine;
require Term::ReadLine::Gnu;  # The other one sucks.

use RevBank::Global;

my %escapes = (a => "\a", r => "\r", n => "\n", t => "\t", 0 => "\0");
my %unescapes = reverse %escapes;
my $unescapes = join "", keys %unescapes;

sub split_input($input) {
    $input =~ s/\s+$//;

    my @terms;
    my $pos = 0;

    while (
        $input =~ m[
            \G \s*+
            (?| (') ( (?: \\. | [^\\']  )*+ ) '   (?=\s|;|$)
              | (") ( (?: \\. | [^\\"]  )*+ ) "   (?=\s|;|$)
              | ()  ( (?: \\. | [^\\;'"\s] )++ )  (?=\s|;|$)
              | ()  (;)
            )
        ]xg
    ) {
        push @terms, (
              (not $1) && $2 eq ";" ? "\0SEPARATOR"
            : (not $1) && $2 eq "abort" ? "\0ABORT"
            : $1 && $2 eq "abort" ? "abort"
            : $2
        );
        $pos = pos($input) || 0;
    }

    # End of string not reached
    return \$pos if $pos < length($input);

    # End of string reached
    s[\\(.)]{ $escapes{$1} // $1 }ge for @terms;
    return @terms;
}

sub reconstruct($word) {
    $word =~ s/([;'"\\])/\\$1/g;
    $word =~ s/\0SEPARATOR/;/;
    $word =~ s/([$unescapes])/\\$unescapes{$1}/g;
    $word = "'$word'" if $word =~ /\s/ or $word eq "abort";
    return $word;
}

sub prompt($prompt, $completions = [], $default = "", $pos = 0, $cart = undef, $plugins = []) {
    state $readline = Term::ReadLine->new($0);

    my $select = IO::Select->new;
    $select->add(\*STDIN);

    if ($prompt) {
        $prompt =~ s/$/:/ if $prompt !~ /[?>](?:\x01[^\x02]*\x02)?$/;
        $prompt .= " ";
    } else {
        # \x01...\x02 = zero width markers for readline
        # \e[...m     = ansi escape (32 = green, 1 = bright)
        $prompt = "\x01\e[32;1m\x02>\x01\e[0m\x02 ";
    }

    my @matches;
    $readline->Attribs->{completion_entry_function} = sub {
        my ($word, $state) = @_;
        return undef if $word eq "";
        @matches = grep /^\Q$word\E/i, @$completions if $state == 0;
        return shift @matches;
    };

    # Term::ReadLine::Gnu (1.37) does not expose rl_completion_case_fold,
    # but it can be assigned through the corresponding .inputrc command.
    $readline->parse_and_bind("set completion-ignore-case on");

    my $done;
    my $input;

    $readline->callback_handler_install($prompt, sub {
        $done = 1;
        $input = shift;
        $readline->callback_handler_remove;
    });

    $readline->insert_text($default);
    $readline->Attribs->{point} = $pos;
    $readline->redisplay();

    my $begin = my $time = time;
    while (not $done) {
        if ($::ABORT_HACK) {
            # Global variable that a signal handling plugin can set.
            # Do not use, but "return ABORT" instead.
            my $reason = $::ABORT_HACK;
            $::ABORT_HACK = 0;
            main::abort($reason);
        }
        if ($select->can_read(.05)) {
            $readline->callback_read_char;
            $begin = $time;
        }
        if (time > $time) {
            $time = time;
            call_hooks(
                "prompt_idle",
                $cart,
                (@$plugins > 1 ? undef : $plugins->[0]), # >1 plugin = main loop
                $time - $begin,
                $readline,
            );
        }
    }

    print "\e[0m";
    defined $input or return;
    $readline->addhistory($input);

    $input =~ s/^\s+//;  # trim leading whitespace
    $input =~ s/\s+$//;  # trim trailing whitespace

    return $input;
}

1;
