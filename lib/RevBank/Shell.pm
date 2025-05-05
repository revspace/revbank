package RevBank::Shell;

use v5.32;
use warnings;
use experimental 'isa';         # stable since v5.36
use experimental 'signatures';  # stable since v5.36

use Carp qw(croak);
use List::Util qw(uniq);
use Sub::Util qw(subname);
use POSIX qw(ttyname);

use RevBank::Plugins;
use RevBank::Global;
use RevBank::Messages;
use RevBank::Cart;
use RevBank::Prompt;

use Exporter qw(import);
our @EXPORT_OK = qw(abort);

our $interactive;

my $cart = RevBank::Cart->new;

my @words;
my $retry;  # reason (text)
my @retry;  # (@accepted, $rejected, [@trailing])

my $prompt;
my @plugins;
my $method;

sub abort {
    @words = ();
    @retry = ();

    my $is_interrupt = @_ && $_[0] eq "^C";
    print "\n" if $is_interrupt;

    if ($is_interrupt and $cart->size and ref $method) {
        call_hooks "interrupt", $cart, \@_;
        call_hooks "cart_changed", $cart;  # XXX ugly; refactor redisplay with instructions
        print "Pressing ^C again will also abort.\n";
    } else {
        print @_, " " unless $is_interrupt;
        call_hooks "abort", $cart, \@_;
        $cart->empty;
        RevBank::FileIO::release_all_locks;
    }
    no warnings qw(exiting);
    redo OUTER;
}

our $in_shell = 0;

sub _shell(@args) {
    croak "Recursive use of non-reentrant function" if $in_shell;
    local $in_shell = 1;

    @words = @args;

    my $one_off = !!@words;

    OUTER: for (;;) {
        if (not @words) {
            call_hooks("cart_changed", $cart) if $cart->changed;
            print "\n";
        }

        $prompt = "";
        @plugins = RevBank::Plugins->new;
        $method = "command";

        PROMPT: {
            if (not @words) {
                if ($one_off) {
                    return if $one_off++ > 1;

                    abort "Incomplete command." if $cart->size;
                    return;
                }

                call_hooks "prompt", $cart, $prompt;
                my $split_input = !ref($method) && $method eq 'command';

                my @completions = uniq 'abort', map $_->Tab($method), @plugins;

                my $default = "";
                my $pos = 0;

                if ($retry) {
                    print "$retry\n";

                    my $word_based = ref($retry[-1]);
                    my @trailing = $word_based ? @{ pop @retry } : ();
                    my @rejected = pop @retry;
                    my @accepted = @retry;

                    if ($word_based) {
                        for (@accepted, @rejected, @trailing) {
                            $_ = RevBank::Prompt::reconstruct($_);
                        }
                    }

                    my $sep = $word_based ? " " : "";
                    $default = join($sep, @accepted, @rejected, @trailing);
                    $pos = @accepted ? length "@accepted$sep" : 0;

                    @retry = ();
                    $retry = 0;
                }

                my $input = RevBank::Prompt::prompt(
                    $prompt, \@completions, $default, $pos, $cart, \@plugins
                );
                if (not defined $input) {
                    return if not ttyname fileno STDIN;  # Controlling terminal gone
                }

                call_hooks "input", $cart, $input, $split_input;

                length $input or redo PROMPT;

                if ($split_input) {
                    @words = RevBank::Prompt::split_input($input);
                    if (ref $words[0]) {
                        my $pos = ${ $words[0] };

                        @retry = @words = ();
                        $retry = "Syntax error.";

                        if ($input =~ /['"]/) {
                            $retry .= " (Quotes must match and (only) be at both ends of a term.)";
                            if (($input =~ tr/'//) == 1 and $input !~ /"/) {
                                $retry .= "\nDid you mean: " . $input =~ s/'/\\'/r;
                            }
                        }

                        push @retry, substr($input, 0, $pos) if $pos > 0;
                        push @retry, substr($input, $pos);
                        redo PROMPT;
                    }
                } else {
                    $input = "\0ABORT" if $input =~ /^\s*abort\s*$/;
                    @words = $input;
                }
            }

            WORD: for (;;) {
                redo PROMPT if not @words;
                abort if grep $_ eq "\0ABORT", @words;

                my $origword = my $word = shift @words;
                my @allwords = ($origword);

                next WORD if $word eq "\0SEPARATOR";

                abort if $method eq "command" and $word eq "abort";  # here, even when quoted


                push @retry, $word;

                ALL_PLUGINS: { PLUGIN: for my $plugin (@plugins) {

                    $cart->prohibit_checkout(
                        @words && $words[0] ne "\0SEPARATOR",
                        "unexpected trailing input (use ';' to separate transactions)."
                    );

                    my $coderef = ref($method) ? $method : $plugin->can($method);
                    my ($mname) = $coderef
                        ? (subname($coderef) eq "__ANON__" ? "" : subname($coderef) . ": ")
                        : (ref($method) ? "" : "$method: ");

                    my ($rv, @rvargs) =

                        ($word =~ /[^\x20-\x7f]/ and $method eq 'command' || !$plugin->AllChars($method))

                        ? (REJECT, "Unexpected control character in input.")
                        : eval { $plugin->$method($cart, $word) };

                    if ($@ isa 'RevBank::Cart::CheckoutProhibited') {
                        @words or die "Internal inconsistency";  # other cause than trailing input

                        push @retry, shift @words;  # reject next word (first of trailing)
                        push @retry, [@words];
                        @words = ();
                        $retry = $@->reason;
                        redo OUTER;
                    } elsif ($@ isa 'RevBank::Exception::RejectInput') {
                        $rv = REJECT;
                        @rvargs = $@->reason;
                    } elsif ($@) {
                        call_hooks "plugin_fail", $plugin->id, "$mname$@";
                        abort;
                    }

                    if (not defined $rv) {
                        call_hooks "plugin_fail", $plugin->id, $mname . "No return code";
                        abort;
                    }
                    if (not ref $rv) {
                        abort "Incomplete command." if $one_off and not @words;

                        if (@words and $words[0] eq "\0SEPARATOR") {
                            push @retry, shift @words;  # reject the ';'
                            push @retry, [@words];
                            @words = ();
                            $retry = "Incomplete command (expected: $rv)";
                            redo OUTER;
                        }

                        $prompt = $rv;
                        @plugins = $plugin;
                        ($method) = @rvargs;
                        if (not ref $method) {
                            call_hooks "plugin_fail", $plugin->id, $mname . "No method supplied";
                            abort;
                        }

                        next WORD;
                    }
                    if ($rv == ABORT or $one_off and $rv == REJECT) {
                        abort(@rvargs);
                    }
                    if ($rv == REDO) {
                        $word = $rvargs[0];
                        call_hooks "redo", $plugin->id, $origword, $word;
                        push @allwords, $word;

                        redo ALL_PLUGINS;
                    }
                    if ($rv == REJECT) {
                        my ($reason) = @rvargs;
                        if (@words) {
                            call_hooks "retry", $plugin->id, $reason, @words ? 1 : 0;
                            push @retry, [@words];
                            @words = ();
                            $retry = $reason;
                            redo OUTER;
                        } else {
                            call_hooks "reject", $plugin->id, $reason, @words ? 1 : 0;
                            @retry = ();
                            redo PROMPT;
                        }
                    }
                    if ($rv == ACCEPT) {
                        if ($method ne 'command' and @words and $words[0] ne "\0SEPARATOR") {
                            @retry = ();  # remove what's already done
                            push @retry, shift @words;  # reject first
                            push @retry, [@words];
                            @words = ();
                            $retry = "Confirm trailing input to execute. (Hint: use ';' after command arguments.)";
                            redo OUTER;
                        }
                        @retry = ();
                        next OUTER;
                    }
                    if ($rv == NEXT) {
                        next PLUGIN if $method eq 'command';
                        call_hooks "plugin_fail", $plugin->id, $mname
                            . "Only 'command' should ever return NEXT.";
                        abort;
                    }
                    call_hooks "plugin_fail", $plugin->id, $mname . "Invalid return value";
                    abort;
                }
                call_hooks "invalid_input", $cart, $origword, $word, \@allwords;
                @retry = ();
                abort if @words;
                redo OUTER;
            } }
        }
    }
}

sub shell() {
    $interactive = 1;
    _shell();
}

sub exec(@args) {
    $interactive = 0;
    _shell(@args);
}

1;
