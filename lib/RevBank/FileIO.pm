package RevBank::FileIO;

use v5.28;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use autodie;
use Fcntl qw(:flock);
use Carp qw(croak);
use Time::HiRes qw(sleep);

my $tempfn = ".revbank.$$";
my $lockfn = ".revbank.global-lock";
my $lockfh;
my $lockcount = 0;

sub get_lock() {
	if (defined $lockfh) {
		die "Fatal inconsistency" if $lockcount < 1;
		return ++$lockcount;
	}
	die "Fatal inconsistency" if $lockcount;

	open $lockfh, ">", $lockfn;
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


	croak "Could not acquire lock on $lockfn; file access failed";
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

sub with_lock :prototype(&) ($code) {
	get_lock;
	my @rv;
	my $rv;
	my $list_context = wantarray;
	eval {
		@rv = $code->() if $list_context;
		$rv = $code->() if not $list_context;
	};
	release_lock;
	croak $@ =~ s/\n$/, called/r if $@;
	return @rv if $list_context;
	return $rv if not $list_context;
}

sub slurp($fn) {
	return with_lock {
		local $/ = wantarray ? "\n" : undef;
		open my $fh, "<", $fn;
		return readline $fh;
	}
}

sub spurt($fn, @data) {
	return with_lock {
		open my $out, ">", $tempfn;
		print $out @data;
		close $out;
		rename $tempfn, $fn;
	};
}

sub append($fn, @data) {
	return with_lock {
		open my $out, ">>", $fn;
		print $out @data;
		close $out;
	};
}

sub rewrite($fn, $sub) {
	return with_lock {
		open my $in, "<", $fn;
		open my $out, ">", $tempfn;
		while (defined(my $line = readline $in)) {
			local $_ = $line;
			my $new = $sub->($line);
			print $out $new if defined $new;
		}
		close $out;
		close $in;
		rename $tempfn, $fn;
	};
}

1;
