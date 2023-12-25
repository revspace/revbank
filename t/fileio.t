# These tests were written by ChatGPT. All four were actually correct the
# first try.

use Test::More;
use File::Temp;

use RevBank::FileIO;

# ChatGPT didn't realise that ::FileIO doesn't export its functions
use RevBank::Global;

subtest "slurp" => sub {
    my $tmp = File::Temp->new();
    my $data = "foo\nbar\nbaz\n";
    print $tmp $data;
    close $tmp;
    my @lines = slurp($tmp->filename);
    is_deeply \@lines, ["foo\n", "bar\n", "baz\n"], "slurp works";
};

subtest "spurt" => sub {
    my $tmp = File::Temp->new();
    spurt($tmp->filename, "foo\nbar\nbaz\n");
    open my $fh, "<", $tmp->filename;
    local $/;
    my $contents = <$fh>;
    close $fh;
    is $contents, "foo\nbar\nbaz\n", "spurt works";
};

subtest "append" => sub {
    my $tmp = File::Temp->new();
    spurt($tmp->filename, "foo\n");
    append($tmp->filename, "bar\n", "baz\n");
    open my $fh, "<", $tmp->filename;
    local $/;
    my $contents = <$fh>;
    close $fh;
    is $contents, "foo\nbar\nbaz\n", "append works";
};

subtest "rewrite" => sub {
    my $tmp = File::Temp->new();
    spurt($tmp->filename, "foo\nbar\nbaz\n");
    rewrite($tmp->filename, sub {
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
