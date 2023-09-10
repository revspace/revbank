package RevBank::TextEditor;

use v5.28;
use warnings;
use experimental 'signatures';  # stable since v5.36

use autodie;
use RevBank::Global;
use Fcntl qw(:flock);
use Carp qw(croak);
use Time::HiRes qw(sleep);

my $tab = 4;

sub _require {
    if (not eval { require Curses::UI }) {
        my $install = -e "/etc/debian_version"
            ? "apt install libcurses-ui-perl"
            : "cpan Curses::UI";

        die "Couldn't load the Perl module Curses::UI.\n" .
            "Please install it! (sudo $install)\n";
    }
}

sub _find_next($win, $textref) {
    my $editor = $win->getobj('editor');
    my $find = $win->getobj('find');
    my $a = $find->getobj('answer');
    my $b = $find->getobj('buttons');

    my $q = $a->get;

    pos($$textref) = $editor->pos;
    my $status = "not found";
    my $offset;
    if ($$textref =~ /\Q$q/gi) {
        $status = "found";
        $offset = $+[0];
    } else {
        $editor->pos(0);
        pos($$textref) = 0;
        if ($$textref =~ /\Q$q/gi) {
            $status = "wrapped";
            $offset = $+[0];
        }
    }

    $find->{-title} = ucfirst $status;
    if ($status ne "not found") {
        $editor->pos($offset);
        $editor->{-search_highlight} = $editor->{-ypos};
    } else {
        $editor->{-search_highlight} = undef;
    }
    $win->draw;
}

sub _find($win) {
    my $editor = $win->getobj('editor');
    my $text = $editor->get;

    my $find = $win->add(
        'find', 'Dialog::Question',
        -question => "Search for:",
        -buttons  => [
            { -label => '[Find next]', -onpress => sub {
                _find_next($win, \$text);
            } },
            { -label => '[Cancel]', -onpress => sub {
                $win->getobj('find')->loose_focus;
                $editor->{-search_highlight} = undef;
            } },
        ]
    );
    my $a = $find->getobj('answer');
    my $b = $find->getobj('buttons');

    $a->onFocus( sub { shift->pos(999) } );

    $a->set_binding(sub {
        $b->{-selected} = 0;  # [Find next]
        $b->focus;
        $b->press_button;
        $win->draw;
    }, Curses::KEY_ENTER());

    $find->set_binding(sub {
        $b->{-selected} = 1;  # [Cancel]
        $b->focus;
        $b->press_button;
        $win->draw;
    }, "\cX", "\cC");
    $b->set_routine('press-button' => sub { $b->press_button });

    $find->modalfocus;
    $win->delete('find');
}

sub _editor($title, $origdata, $readonly = 0) {
    our $cui ||= Curses::UI->new;
    my $win = $cui->add('main', 'Window');
    $title = $readonly
        ? "[$title]  Press q to quit"
        : "[$title]  Ctrl+X: exit  Ctrl+F: find  Ctrl+C/K/V: copy/cut/paste";

    my $editor = $win->add(
        'editor', 'TextEditor',
        -title      => $title,
        -text       => $origdata,
        -border     => 1,
        -padbottom  => 1,  # ibm3151/screen lastline corner glitch workaround
        -wrapping   => 0,
        -hscrollbar => 0,
        -vscrollbar => 0,
        -pos        => ($readonly == 2 ? length($origdata) : 0),
        #-readonly => !!$readonly  # does not support -pos
    );

    my $return;

    if ($readonly) {
        $editor->readonly(1);  # must be before bindings
        $editor->set_binding(sub { $cui->mainloopExit }, "q") if $readonly;
    } else {
        my @keys = (
            [ Curses::KEY_HOME() => 'cursor-scrlinestart' ],
            [ Curses::KEY_END()  => 'cursor-scrlineend' ],
            [ "\cK" => 'delete-line' ],  # nano (can't do meta/alt for M-m)
            [ "\cU" => 'paste' ],        # nano
            [ "\c[" => sub { } ],
            [ "\cL" => sub { $cui->draw } ],
            [ "\c^" => sub { $editor->pos(0) } ],
            [ "\c_" => sub { $editor->pos(length($editor->get)) } ],
            [ "\cI" => sub { $editor->add_string(" " x ($tab - ($editor->{-xpos} % $tab))) } ],
            [ "\cS" => sub { $cui->dialog("Enable flow control :)") } ],
            [ "\cQ" => sub {} ],
            [ "\cC" => sub { $editor->{-pastebuffer} = $editor->getline_at_ypos($editor->{-ypos}) } ],
            [ "\cF" => sub { _find($win) } ],
            [ "\cX" => sub {
                if ($editor->get ne $origdata) {
                    my $answer = $cui->dialog(
                        -message => "Save changes?",
                        -buttons => [
                            { -label => "[Save]",    -value => 1 },
                            { -label => "[Discard]", -value => 0 },
                            { -label => "[Cancel]",  -value => -1 },
                        ],
                        -values => [ 1, 0 ],
                    );
                    $return = $editor->get if $answer == 1;
                    $cui->mainloopExit     if $answer >= 0;
                } else {
                    $cui->mainloopExit;
                }
            } ],
        );

        $editor->set_binding(reverse @$_) for @keys;
    }
    $editor->focus();

    $cui->mainloop;
    $cui->leave_curses;
    $cui->delete('main');

    return $return;
}

sub edit($filename) {
    _require();

    open my $fh, ">>", $filename;
    flock $fh, LOCK_EX | LOCK_NB
        or die "Someone else is alreading editing $filename.\n";

    my $save = _editor($filename, scalar slurp $filename);

    if (defined $save) {
        spurt $filename, $save;
        print "$filename updated.\n";
    } else {
        print "$filename not changed.\n";
    }
}

sub pager($title, $data) {
    _require();
    _editor($title, $data, 1);
}

sub logpager($title, $data) {
    _require();
    _editor($title, $data, 2);
}

1;
