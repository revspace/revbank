# These tests were originally written by ChatGPT. All four were actually
# correct the first try.

use Test2::V0;
use File::Temp ();
use File::Basename qw(basename);

use RevBank::FileIO;

# ChatGPT didn't realise that ::FileIO doesn't export its functions
use RevBank::Global;

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;

sub _newtmp {
    File::Temp->new(DIR => $ENV{REVBANK_DATADIR});
}

subtest "slurp" => sub {
    my $tmp = _newtmp;
    my $data = "foo\nbar\nbaz\n";
    print $tmp $data;
    close $tmp;
    my @lines = slurp(basename($tmp->filename));
    is \@lines, ["foo\n", "bar\n", "baz\n"], "slurp works";
};

subtest "spurt" => sub {
    my $tmp = _newtmp;
    spurt(basename($tmp->filename), "foo\nbar\nbaz\n");
    open my $fh, "<", $tmp->filename;
    local $/;
    my $contents = <$fh>;
    close $fh;
    is $contents, "foo\nbar\nbaz\n", "spurt works";
};

subtest "append" => sub {
    my $tmp = _newtmp;
    spurt(basename($tmp->filename), "foo\n");
    append(basename($tmp->filename), "bar\n", "baz\n");
    open my $fh, "<", $tmp->filename;
    local $/;
    my $contents = <$fh>;
    close $fh;
    is $contents, "foo\nbar\nbaz\n", "append works";
};

subtest "rewrite" => sub {
    my $tmp = _newtmp;
    spurt(basename($tmp->filename), "foo\nbar\nbaz\n");
    rewrite(basename($tmp->filename), sub {
        my ($line) = @_;
        if ($line =~ /^bar/) {
            return "quux\n";
        }
        return $line;
    });
    open my $fh, "<", $tmp->filename;
    local $/;
    my $contents = <$fh>;
    close $fh;
    is $contents, "foo\nquux\nbaz\n", "rewrite works";
};

done_testing();
