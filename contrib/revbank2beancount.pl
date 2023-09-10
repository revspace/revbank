#!/usr/bin/env perl

=head1 DESCRIPTION

This script translates a RevBank log file to Beancount 2 format, which can then
be used with beancount tools such as the web interface Fava:

	perl contrib/revbank-log2beancount.pl > revbank.beancount
	fava revbank.beancount

Call this script from the directory that contains C<revbank.accounts> and
C<.revbank.log>. Optionally, a different log file can be given on the command
line, to be used instead of C<.revbank.log>.

=head2 Caveats

This results in an incomplete administration, as RevBank will undoubtedly be
unaware of most expenses, and income through contribution fees. So while the
total numbers (like "net profit") are mostly useless, the numbers for
individual accounts may be insightful, and it provides pretty charts.

RevBank uses datetime with a 1 second resolution, but Beancount 2 only supports
date granularity, so it can't give intradate numbers. The time is recorded as
metadata but otherwise ignored by Beancount; they postings are in the right
order because it's a stable sort, not because the time is taken into account.

Note that compared to a typical Beancount ledger, all amounts will be flipped,
i.e. -42 becomes +42 and +42 becomes -42. This is because RevBank's bookkeeping
is done from the users' perspectives, rather than that of the organization.
Incidentally, the resulting numbers will also make more intuitive sense as
income is now positive and expenses are negative - which is not what a typical
Beancount administration would look like, but would seem more logical to most
lay persons.

Beancount transaction descriptions are attached to the booking, not to its
individual postings, while RevBank has a different description for each
account, again because it works from the perspectives of the users. The
descriptions are converted as string metadata. To view them in Fava, enable
both Metadata and Postings.

Fava beans can be deadly for persons with G6PD deficiency, because the beans
contain vicine, which is toxic to them as vicine oxidises glutathione faster
than these people can regenerate it. The resulting hemolytic anemia due to
premature breakdown of red blood cells can culminate in a fatal hemolytic
crisis. G6PD deficiency is a hereditary enzyme deficiency that is estimated to
affect 5% of Earth's human population.

=cut

use v5.32;
use warnings;
use autodie;

use FindBin qw($RealBin);
use lib "$RealBin/../lib";
use RevBank::Amount;

my %transactions;
my @transaction_ids;  # keep order: future revbank might have non-monotonic ids
my %balances;
my $currency = "EUR";
my $first_date = "9999-99-99";
my $fn = shift;

print qq{option "operating_currency" "$currency"\n};

sub rb2bc {
	# TODO Rewrite. What a mess.

	local $_ = join ":", map ucfirst, split m[/], shift;
	s/_/-/g;
	s/^-cash$/-cash:Box/;  # skimmed would be sub category
	return "Expenses:Reimbursed" if $_ eq "-deposits:Reimburse";
	return "Assets:\u$_" if /^(?:-cash|-deposits)\b/i and s/^-//;
	return "Expenses:\u$_" if /^(?:-expenses)\b/i and s/^-//;
	return "Liabilities:Ibuttonborg" if $_ eq "+ibuttonborg";
	return "Equity:\u$_" if s/^-//;
	return "Income:\u$_" if s/^\+//;
	return "Liabilities:$_";
}

open my $fh, $fn || ".revbank.log";

while (defined(my $line = readline $fh)) {
	if ($line =~ /CHECKOUT/) {
		my ($date, $time, $id, $account, $dir, $qty, $amount, $desc) = $line =~ m[
			^(\d\d\d\d-\d\d-\d\d)_(\d\d:\d\d:\d\d)  # date_time
			\s++ CHECKOUT
			\s++ (\S++)            # transaction id
			\s++ (\S++)            # account name
			\s++ (GAIN|LOSE|====)  # direction
			\s++ (\d++)            # quantity
			\s++ ([\d.]++)         # total amount (absolute)
			\s++ \#\s(.*)          # description
		]x or warn;
	
		$first_date = $date if $date lt $first_date;

		if (not exists $transactions{$id}) {
			$transactions{$id} = { date => $date, time => $time };
			push @transaction_ids, $id;
		}

		push @{ $transactions{$id}{legs} }, {
			account => $account,
			dir     => $dir,
			amount  => $amount,
			desc    => $desc,
		};
	}

	elsif ($line =~ /BALANCE/) {
		my ($date, $id, $account, $balance) = $line =~ m[
			^(\d\d\d\d-\d\d-\d\d)_\S++  # date
			\s++ BALANCE
			\s++ (\S++)         # transaction id
			\s++ (\S++)         # account name
			\s++ had
			\s++ ([+-][\d.]++)  # account balance before transaction
		]x or warn;

		# This uses the fact that revbank will *always* emit a BALANCE event
		# for every account modified by a CHECKOUT event, and that transactions
		# will be in chronological order in the log. That is, the first old
		# balance will be the opening balance, regardless of the corresponding
		# transaction id.
		$balances{$account} //= $balance;
	}
}

print "$first_date open Equity:Opening-Balances\n";
print "$first_date open Equity:Undo\n";

# Opening balances for accounts that had transactions
for my $account (sort keys %balances) {
	printf "$first_date open %s $currency\n", rb2bc($account);
	print qq{$first_date * "Opening balance for $account"\n};
	printf(
		"  %s %s $currency\n",
		rb2bc($account),
		RevBank::Amount->parse_string($balances{$account})
	);
	printf "  Equity:Opening-Balances\n\n";

}

# Transactions
for my $id (@transaction_ids) {
	my $txn = $transactions{$id};

	print qq{$txn->{date} * "RevBank-transaction $id"\n};
	print qq{  time: "$txn->{time}"\n};

	for my $leg (@{ $txn->{legs} }) {
		printf(
			qq{  %s %s $currency\n    description: "%s"\n},
			rb2bc($leg->{account}),
			($leg->{dir} eq 'GAIN' ? +1 : -1) * RevBank::Amount->parse_string($leg->{amount}),
			$leg->{desc} =~ s/\"/\\\"/gr
		);
	}
	print "\n";
}

# TODO: read revbank.accounts and "open" beancount accounts for all accounts
# that didn't have any transactions.
