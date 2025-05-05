package RevBank::FileIO;

use v5.32;
use warnings;
use experimental 'signatures';  # stable since v5.36

use autodie;
use Fcntl qw(:flock);
use Carp qw(croak);
use Time::HiRes qw(sleep);
use File::Path qw(make_path);
use FindBin qw($RealBin);

my $DATADIR = \($ENV{REVBANK_DATADIR} ||= "$ENV{HOME}/.revbank");

my $tempfn = ".write.$$";
my $lockfn = ".global-lock";
my $lockfh;
my $lockcount = 0;

sub get_lock() {
	if (defined $lockfh) {
		die "Fatal inconsistency" if $lockcount < 1;
		return ++$lockcount;
	}
	die "Fatal inconsistency" if $lockcount;

	open $lockfh, ">", "$$DATADIR/$lockfn";
	my $attempt = 1;

	my $debug = !!$ENV{REVBANK_DEBUG};
	FLOCK: {
		if (flock $lockfh, LOCK_EX | LOCK_NB) {
			syswrite $lockfh, $$;
			return ++$lockcount;
		}

		if (($attempt % 50) == 0 or $debug) {
			warn "Another revbank instance has the global lock. Waiting for it to finish...\n"
		}
		sleep .1;

		$attempt++;
		redo FLOCK;
	}


	croak "Could not acquire lock on $$DATADIR/$lockfn; file access failed";
}

sub release_lock() {
	if (not defined $lockfh) {
		die "Fatal inconsistency" if $lockcount;
		return;
	}
	die "Fatal inconsistency" if $lockcount < 1;

	if (--$lockcount == 0) {
		flock $lockfh, LOCK_UN;
		close $lockfh;

		undef $lockfh;
	}
}

sub release_all_locks() {
	release_lock while $lockcount;
}

sub with_lock :prototype(&) ($code) {
	my $skip = $ENV{REVBANK_SKIP_LOCK};
	get_lock unless $skip;
	my @rv;
	my $rv;
	my $list_context = wantarray;
	eval {
		@rv = $code->() if $list_context;
		$rv = $code->() if not $list_context;
	};
	release_lock unless $skip;
	croak $@ =~ s/\.?\n$/, rethrown/r if $@;
	return @rv if $list_context;
	return $rv if not $list_context;
}

sub slurp($fn) {
	return with_lock {
		return _slurp("$$DATADIR/$fn");
	}
}

sub _slurp($fn) {
	local $/ = wantarray ? "\n" : undef;
	open my $fh, "<", $fn;
	return readline $fh;
}

sub spurt($fn, @data) {
	return with_lock {
		open my $out, ">", "$$DATADIR/$tempfn";
		print $out @data;
		close $out;
		rename "$$DATADIR/$tempfn", "$$DATADIR/$fn";
	};
}

sub append($fn, @data) {
	return with_lock {
		open my $out, ">>", "$$DATADIR/$fn";
		print $out @data;
		close $out;
	};
}

sub rewrite($fn, $sub) {
	return with_lock {
		open my $in, "<", "$$DATADIR/$fn";
		open my $out, ">", "$$DATADIR/$tempfn";
		while (defined(my $line = readline $in)) {
			local $_ = $line;
			my $new = $sub->($line);
			print $out $new if defined $new;
		}
		close $out;
		close $in;
		rename "$$DATADIR/$tempfn", "$$DATADIR/$fn";
	};
}

sub mtime($fn) {
	return +(stat "$$DATADIR/$fn")[9];
}

sub create_datadir() {
	return if -d $ENV{REVBANK_DATADIR};

	make_path $ENV{REVBANK_DATADIR}
		or die "$0: $ENV{REVBANK_DATADIR}: Can't create directory.\n";
	spurt "accounts", "";
	spurt "nextid", "1";
	spurt $_, RevBank::FileIO::_slurp("$RealBin/data/$_")
		for qw(plugins products market);
}

1;
