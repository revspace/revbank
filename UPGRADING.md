# Upgrade procedure

1. Stop any running `revbank` instances, or at least make sure nobody will be
   using RevBank during the upgrade.
2. **Make a backup** of your RevBank data and code repo(s).
3. Read this file :) to see if you need to change anything. Check your current
   version and read everything pertaining to newer versions, from oldest to newest (top).
4. Use `git pull --rebase` in the right directory. Don't ignore its output,
   because you may need to manually resolve merge conflicts.
5. (Re)start `revbank`. If the old version was still running, use the `restart`
   command before issuing any other commands.

The standard deprecation cycle is 2 years. **It is recommended that you upgrade
RevBank at least once a year.**

While you're at it, upgrade the rest of your system too. RevBank currently
supports Perl versions down to 5.32 (2020), which is in Debian 11 "bullseye"
(oldstable). Once Debian 13 "trixie" is released as stable (expected in 2025)
and 12 "bookworm" becomes the new oldstable, RevBank will begin to require Perl
5.36 (2022).

# (2025-05-06) RevBank 10.2.0

No breaking change, but a change that several RevBank sysadmins have requested
over the years.

It is now possible to load plugins from other directories. It is suggested that
you put your custom plugins in a separate directory (hint: git init :)), and
refer to them *by path* in `~/revbank/plugins`.

# (2025-05-05) RevBank 10.0.0

Major breaking change!

Instead of dumping many files in the working directory, RevBank now uses a
(configurable) data directory. This is `~/.revbank` by default but it can be
overridden with the environment variable `REVBANK_DATADIR` or `--datadir` on
the command line. (If both are specified, the latter overrules the former.)

This change makes it easier to make backups of just the data files, and allows
running `revbank` from any working directory.

## Create a data directory

Create a directory named `.revbank` in the home directory of the user account
that runs `revbank`:

```sh
mkdir ~/.revbank
```

If this already exists, you've probably executed `revbank` before reading these
instructions. Check that the files are just the example files that RevBank put
there, and just delete them.

## Rename data files

To migrate your existing files, execute from the directory that has them:

```sh
mv revbank.accounts   ~/.revbank/accounts
mv revbank.market     ~/.revbank/market
mv revbank.plugins    ~/.revbank/plugins
mv revbank.products   ~/.revbank/products
mv revbank.sales      ~/.revbank/revspace_mqtt
mv revbank.statiegeld ~/.revbank/statiegeld
mv revbank.stock      ~/.revbank/stock
mv revbank.vat        ~/.revbank/vat
mv revbank.voorraad   ~/.revbank/stock  # overwrites .stock if both exist
mv revbank.warnings   ~/.revbank/warnings
mv .revbank.nextid    ~/.revbank/nextid
mv .revbank.oepl      ~/.revbank/oepl
mv .revbank.undo      ~/.revbank/undo
mv .revbank.log       ~/.revbank/log
rm .revbank.global-lock
```
Some of these only exist if you use certain plugins, so don't worry about error
messages saying the files don't exist.

Note, if you've customized/forked the `revspace_mqtt` plugin, that its filename
has changed to match the name of the plugin.

## If the log file was append-only

If you get *Operation not permitted* on `.revbank.log` and/or `.revbank.undo`,
you probably have protected them with `chattr +a` to only allow appending. Use
`chattr -a` (as root!) to remove the protection, then move the file, then `+a`
it again.

## If you used git before

Many RevBank installations had the data files in git, and this change is there
to make that easier and to disentangle the data files from the code repository.

Unfortunately, moving the existing git repo can be tough and takes some real
git experience to do correctly, because everyone's repo probably looks a bit
different. But in general: `git mv revbank.foo foo` instead of `mv revbank.foo
~/.revbank/foo`, then move both `.git` and the actual revbank files to the new
directory.

It may be easier to start over, using the new git plugin:

## Use git

Many spaces had their own plugin for committing changes to git. RevBank now
comes with a standard plugin, `git`, that does this in a more generic way. You
may want to enable it by adding it to `~/.revbank/plugins`.

Note: this plugin does not `git push` to a remote repository. You could do that
with a cron job or a systemd timer, which also spares the RevBank end user from
long delays if the network is borked.

Note: this plugin creates a `.gitignore` file to ignore the log files because
it is generally not advised to keep log files in a revision control system. If
you do want to keep the log files in git, edit `~/.revbank/.gitignore` after it
has been created. It's probably better to use a real backup solution, not
(just) git.

## Update external things that use the RevBank data files

Don't forget to update any backup configuration, scripts, and other things that
use the RevBank data files.

## Update custom plugins

The functions `slurp` and `spurt` will now prefix the path of the datadir to
the given filename. Previously they worked from the current working directory.

If you're reading or writing any of the files listed above, those needs to be
changed.

# (2025-04-10) RevBank 9.0.0

There are no breaking changes in this release, but the old names mentioned
below are now deprecated. All custom plugins that use these identifiers need to
be updated eventually.

In many places, the term 'user' has been replaced with the term 'account', to
more accurately describe the current state of RevBank, which has non-user
accounts in addition to user accounts.

The term 'account' is now the generic term (visible and hidden accounts), but
'user' or 'username' is still used where only user accounts (visible accounts)
are valid.

## Renamed hooks

| Old name            | New name               |
|---------------------|------------------------|
| `hook_user_created` | `hook_account_created` |
| `hook_user_balance` | `hook_account_balance` |

The new hooks are added in addition to the old ones.

The old hooks will be removed in a future version, after 2027-05-01.

## Renamed global identifiers

| Old name                      | New name                            |
|-------------------------------|-------------------------------------|
| `RevBank::Users::assert_user` | `RevBank::Accounts::assert_account` |
| `RevBank::Users`              | `RevBank::Accounts`                 |
| `$contra->{user}`             | `$contra->{account}`                |
| `$entry->user`                | `$entry->account`                   |

Custom plugins might be affected by this change, but most won't.

`->{user}` was kept for read-only use, and will be removed after 2027-05-01.
(This is technically a breaking change, but changing that value from a plugin
would probably break things anyway.)

The old functions/method names are aliases for the new ones, and will be
removed after 2027-05-01.

## Not renamed

The following remain unchanged, as they only or mostly pertain to visible
accounts, which are primarily intended as user accounts:

- `parse_user()` function
- `hook_user_info`
- `adduser` command
- `users` plugin

The following remain unchanged (for now) because external scripts might break
if these were changed:
- `NEWUSER` in the log file

# (2024-12-26) RevBank 8.0.0

Another breaking change, another major version upgrade due to semantic versioning!

## Breaking change:

This is very unlikely to affect anyone, but still: `percent` addons (like
discounts) applied by `read_products` now have the calculated price in
`->{price}`, and the percent amount was moved to `->{percent}`, which was
previously just a boolean.

This change has had no deprecation cycle because I don't think anyone would be
using this in custom code. But if you did use this feature in a custom plugin
(wow, I really want to know all about it!), just change `price` to `percent`
where appropriate.

## Non-breaking changes:

* `RevBank::Plugins::products::read_products` was moved to
  `RevBank::Products::read_products`, but the old symbol still works.

* `read_products` gained some additional features, such as price tag
  calculations. Top-level products now have `->{tag_price}`, `->{hidden_fees}`,
  and `->{total_price}` in addition to the existing base price which is still
  in `->{price}`.

* Because `read_products` is now in a module, you can `use RevBank::Products;`
  in your own scripts so you don't have to write your own parser for
  `revbank.products` anymore. (Don't forget to `use lib "path/to/lib";` first!)

The calculated tag prices are not displayed anywhere in RevBank, but meant for
an upcoming feature which is to generate images for electronic price tags. To
exclude addon prices from the price tag (as is customary with
statiegeld/pfand/deposits), add the new `#OPAQUE` hashtag to the respective
addon lines in `revbank.products`.

## Deprecation announcement

* Support for the old file format for `revbank.products` will be removed in
  2026. The new format was introduced in 6.0.0 in January 2024, but the old
  format still works (and it gives a lot of warnings if you use it). See below
  for how to update your products file.

* The plugin `deprecated_raw` will be removed after February 2025. This plugin
  warns tells users to use `withdraw` or `unlisted` instead of a raw amount,
  after support for that was dropped in 3.3 in June 2022.

# (2024-11-17) RevBank 7.1.0

The new plugin `nomoney` is enabled by default. For rationale, see
https://forum.revspace.nl/t/inkoopacties-via-revbank/469.

Whether this constitutes a breaking change is debatable, and it wasn't added to
this file until 2025-03-06. It's a new feature, but the feature is to disallow
some transactions which used to be allowed. (Specifically, it denies
transactions if the user has insufficient balance; by default only for
give/take/withdraw, but the list of affected plugins can be customized.)


# (2024-10-18) RevBank 7.0.0

Support for unbalanced entries has been removed, ensuring a pure double-entry
bookkeeping system. Grep your log for the string `UNBALANCED` if you're not
sure that all your custom plugins are already well-behaved. Note that since
unbalanced transactions are no longer supported, transactions from before that
change can't be reverted with `undo`.

There are no other changes in this version.

Since all transactions are now balanced, the sum of all the balances is
`revbank.accounts` will remain fixed forever. It is recommended to make that
sum equal to `0.00` (only once) by adding a dummy account which acts a
retroactive opening balance:

```sh
perl -Ilib -MRevBank::Amount -lane'$sum += RevBank::Amount->parse_string($F[1])
}{ printf "-deposits/balance %s\n", -$sum if $sum;' revbank.accounts >> revbank.accounts
```

From that point forward, the sum of all the values in the second column of the
`revbank.accounts` file should forever be 0.00; if it's not, either someone
tampered with the file or there is data corruption, and the cause should be
investigated and corrected.

```sh
perl -Ilib -MRevBank::Amount -lane'$sum += RevBank::Amount->parse_string($F[1])
}{ print $sum' revbank.accounts
```

# (2024-01-20) RevBank 6.0.0

Note that the changes to `revbank.products` do NOT apply to `revbank.market`
and other files.

## Update your `revbank.products` file

TL;DR: Product descriptions now need `"quotes"` around them.

This version comes with breaking changes to the `revbank.products` syntax, to
expand the capabilities of the file in a more future-proof way. Bitlair
(Hackerspace Amersfoort) has requested a way to add metadata to products for
automation, which together with recent other additions to the format, made
clear a more structured approach was needed.

The line format for the products file is now like the input format of the
command line interface. This means that if product descriptions contain spaces,
as they typically do, quotes are needed around them. You can pick between
`"double"` and `'single'` quotes. Any backslashes and quotes within the same
kind of quotes need escaping by adding a `\` in front, e.g. `\"` and `\\`.

```
# Old format:
product_id    0.42    Can't think of a good description +addon1 +addon2

# New format, recommended style:
product_id    0.42    "Can't think of a good description" +addon1 +addon2

# Automatically generated? You may wish to quote all fields:
"product_id" "0.42" "Can't think of a good description" "+addon1" "+addon2"

# Escaping also works:
product_id 0.42 Can\'t\ think\ of\ a\ good\ description +addon1 +addon2
```

To convert your `revbank.products` file to the recommended style automatically,
you could use:

```sh
# The following is one command. It was obviously not optimized for readability :)

perl -i.backupv6 -ple'unless (/^\s*#/ or /^\s*$/) {
  my ($pre, $desc) = /(^\s*\S+\s+\S+\s*)(.*)/; $pre .= " " if $pre !~ /\s$/;
  my @a; unshift @a, $1 while $desc =~ s/\s\+(\S+)$//;
  $desc =~ s/([\"\\])/\\$1/g; $_ = "$pre\"$desc\"";
  for my $a (@a) { $_ .= " +$a" }
}' revbank.products
```

Note that this will leave commented lines unchanged! If those contain disabled
products, you'll have to add the quotes yourself.

## New feature: hashtags in `revbank.products`

After the description field, you can add hashtag fields. These begin with `#`
and may take the form of a lone `#hashtag`, or they may be used as a
`#key=value` pair. The hashtags can be read by plugins. Out of the box, they
currently do nothing.

```
8711327538481  0.80  "Ola Liuk"   #ah=wi162664 #q=8
8712100340666  0.45  "Ola Raket"  #ah=wi209562 #q=12
5000112659184,5000112658873  0.95  "Coca-Cola Cola Zero Sugar (33 cl)" #sligro +sb

# equivalent:
"8711327538481" "0.80" "Ola Liuk" "#ah=wi162664" "#q=8"
```

See https://github.com/bitlair/revbank-inflatinator/ for a possible use of adding metadata.

# (2023-12-26) RevBank 5.0.0

This version comes with breaking changes to the command line syntax, to shield
overconfident users of the interface for advanced users from several classes of
common mistakes, and to add support for quoted and escaped strings to this
interface.

Basically, you can now use `;` to separate multiple commands on a single line
of input, and in some cases this is mandatory.

## Limited set of characters allowed in usernames and product IDs

Historically, RevBank has allowed almost every character as a valid character,
because it wasn't known if these would show up in barcodes. In more than 13
years of real world use, though, it seems that barcodes and usernames with
"special" characters are incredibly uncommon.

Since `' " \ ;` now have special meanings, they are no longer supported in
product IDs. In theory, they could be quoted or escaped, but barcode scanners
don't know that. Existing users with those characters in their names can
continue to use their accounts by quoting or escaping them.

New usernames must now only contain the characters from the set 
`A-Z a-z 0-9 _ - + / ^ * [] {}` and the first character must not be any of
`- + / ^ *`.

## Update scripts that run revbank commands

When providing multiple commands on a single line, RevBank now requires a
separating `;` after commands that finalize transactions, and after commands
that take arguments.

End-users are guided interactively to deal with the change, but automated
commands require changing. Specifically, add a `;` between a multi-word command
and the final username (e.g. `give *lasercutter 10; xyzzy`) and in between
transactions.

## Update your custom plugins

* The undocumented feature `ROLLBACK_UNDO` is gone. Use `return ABORT` in a
  function called `hook_undo` instead.
* Plugins are now evaluated with an implicit `use v5.32;` which enables many
  new Perl features and disables some old ones. Specifically, the old-style
  "indirect object notation" is disabled, which means that `new Foo(...)`
  should be rewritten as `Foo->new(...)`.
* `$cart->checkout` now throws an exception if there is unprocessed input in
  the queue (the user can use `;` if it was intentional). There were always
  reasons a checkout could fail, but now it is much more likely. Things that
  should only happen if the checkout succeeds, should be put *after* the call,
  or in a hook.

# (2023-11-05) RevBank 4.2.0

Accounts that begin with `*` are now special: like hidden accounts, they do not
count towards the grand total, but unlike hidden accouns, they can be used as
normal user accounts too.

The intended application is for liabilities accounts that are also used
directly for revenues and expenses.

They can be used with or without the `*` prefix, e.g. the account
`*lasercutter` can also be used as `lasercutter`. Such accounts cannot be
created from within the software: to create a user-accessible special account,
you need to edit `revbank.accounts` manually.

When upgrading, check that no accounts beginning with `*` already exist.

# (2023-09-20) RevBank 4.0.0

## You must pick a transaction ID style

Transaction IDs are now sequential for better auditability. In previous
versions, they were timestamps (unix time minus 1.3e9).

Because of this change, you must restart *every* running RevBank instance or
else the transaction IDs will no longer be monotonic between processes, which
would be bad.

You should choose which transaction IDs you want, and write your choice to a
file called `.revbank.nextid`.

### Option 1: continue with large IDs but increment by 1 from now on

**If you don't write a `.revbank.nextid` file,** RevBank will create one for
you, but you might not like it. It will generate one more timestamp based ID
and then increment that for subsequent transactions. This has the advantage of
not having the one-time break of monotonicity, but you will be stuck with the
long IDs and they will no longer convey time information.

### Option 2: beginning a new sequence

Anything that works with Perl's `++` operator will work, and that gives a few
options. If you want to start over with transaction ID **1**, write that to the
file:

```sh
echo 1 > .revbank.nextid
```

You can also use padding zeroes if you like. They will safely overflow to use
an extra digit after all-nines is reached:

```sh
echo 00001 > .revbank.nextid
```

(You can also use alphanumeric IDs, but I'm not sure if you should.)

Or, if you still have all the logs from since you started using RevBank, you
can pretend RevBank has always had simple incremental transaction IDs and use
the number of distinct transaction IDs from the log file as the basis for the
next ID:

```sh
# This is my personal preference

perl -lane'BEGIN { $max = time() - 1.3e9 }
    /^\d+$/ and $_ > 0 and $_ < $max and $x{$_}++ for @F[1, 2];
    }{ print 1 + keys %x' .revbank.log > .revbank.nextid

# Note: use multiple filenames (e.g. .revbank.log*) if you rotate log files
# (like when you have yearly logs).
```

This is safe because the timestamp based IDs were huge and are unlikely to
overlap at least the next few decades.

### Option 3: keeping the legacy transaction ID scheme (for now)

Finally, for those who really don't want to change the scheme now, the old
system can be retained by writing the special-cased value `LEGACY`. This
feature will be supported at least until 2024-01-01, but might be removed after
if nobody tries to convince me otherwise.

```sh
echo LEGACY > .revbank.nextid
```

## Update `revbank.plugins`

There are a few new plugins that you may wish to enable. Some have been around
longer than RevBank 3.9, but haven't been mentioned in UPGRADING.md before.

### `vat`

Automatically calculate and set aside VAT ("BTW" in Dutch) on generated
revenue. You will probably not need this. Before enabling this plugin, read the
documentation in `plugins/vat.pod` first.

### `regex_gtin`

To support GS1 Digital Links and other GS1 barcodes. The DL are a new way for
QR codes that contain product IDs and other metadata while also being usable
for promotional stuff. At least one popular brand of soft drinks is already
using them. There's a huge standard that describes these codes, but basically,
they're URLs with /01/ and a 14-digit product ID in them. Enabling this plugin
is probably useful and harmless; add it to `revbank.plugins` *after* plugins
that deal with product IDs like `products` and `market`.

### `regex_angel`

Replaces custom SHA2017/MCH2022 angel badge hacks. Add after `users` in
`revbank.plugins` after removing your custom plugin for `angel-` barcodes.

### `adduser_note`

Add *before* `adduser` in `revbank.plugins`. This will inform new users that
RevBank is insecure by design and what implications that can have. Enabling
this plugin is recommended.

### `statiegeld` and `statiegeld_tokens`

Charge and refund container deposit return ("statiegeld" in Dutch). Read the
documentation in `plugins/statiegeld.pod` and `plugins/statiegeld_tokens.pod`
for instructions.

### `cash_drawer`

If you have an electronic cash drawer, copy or change this plugin and add code
to trigger it whenever something is done that involves cash.

## Deprecation note

RevBank has supported "doubly entry bookkeeping" since version 3.4 last year.
For backwards compatibility with custom plugins, support for unbalanced
transactions was retained.

Support for unbalanced transactions will be removed after 2024-06-10, after a
period of 2 years after the introduction of balanced transactions. If you're
using custom plugins, grep your log file for the text "UNBALANCED ENTRY" to see
if changes are needed.

# (2023-08-21) RevBank 3.9

A tiny change that could break things: the shebang was changed from
`#!/usr/bin/perl` to the more modern `#!/usr/bin/env perl`.

In the unlikely event that your system has multiple perl executables in the
search path of `PATH`, this change could mean that revbank now uses a different
perl, in which case you may have to reinstall the required Perl libraries.

Background: NixOS doesn't follow the previously uni(x)versal convention that,
when Perl is available, an executable exists at `/usr/bin/perl`. The only
stable paths that NixOS provides for shebangs are `#!/bin/sh` or
`#!/usr/bin/env`. There were always pros and cons to switching the shebang to
`env` (e.g. for use with perlbrew), but learning about Nix has tipped the
scales for me. (The performance penalty is not relevant for RevBank.)

# (2023-02-12) RevBank 3.8

## Update your `revbank.plugins`

Deduplication is moved from individual plugins to a plugin that does that. If
you want to keep deduplication of cart items, and you probably do want that,
add `deduplicate` to `revbank.plugins` just below `repeat`.

The deprecation warning was moved from the `withdraw` plugin to a new plugin
called `deprecated_raw`. If you're upgrading from an older versions and some of
your users have been around since before the withdraw/unlisted split, you may
want to keep the deprecation warning. But for new RevBank installations it does
not make sense. To keep providing these warnings to users that enter raw
amounts, add `deprecated_raw` to the very end of `revbank.plugins`.

# (2022-12-25) RevBank 3.6

## Update your `revbank.plugins`

The `edit` command is now in its own plugin, so that it can be disabled (this
has been requested several times). To keep the ability to edit the products
list from within RevBank, add `edit` to `revbank.plugins`.

## Check your `revbank.products`

> Added 2024-01-20 v6.0.0: if you're upgrading to v6.0.0 from a version before
> v3.6, instead of following these instructions, you can just add quotes to the
> descriptions (when using the perl oneliner from the v6.0.0 upgrade
> instructions, check if any `+something` that got placed outside of the quotes
> should have been within the quotes.)

~~There's new syntax for `revbank.products`: addons. Check that your lines don't
have `+foo` at the end, where `foo` can be anything.~~

~~Also check that you don't have any product ids that start with `+`; those can
no longer be entered as this syntax now has special semantics.~~

~~So these don't work as before:~~

    example_id      1.00  Example product +something
    +something      1.00  Product id that starts with plus
    example,+alias  1.00  Alias that starts with plus

~~These will keep working as they were:~~

    example_id1     1.00  Example product+something
    example_id2     1.00  Example product + something
    more_stuff      1.00  Example product with +something but not at the end
    bbq             1.00  3+ pieces of meat

## New features in `products` plugin

There are several new features that you may wish to take advantage of. By
combining the new features, powerful things can be done that previously
required custom plugins.

The syntax for `revbank.products` has become complex. Please refer to the new
documentation in [products.pod](plugins/products.pod) for details.

### Negative prices (add money to account)

Support for non-positive prices was requested several times over the years and
has now finally been implemented.

It's now possible to have a product with a negative amount, which when "bought"
will cause the user to receive money instead of spending it.

### Product addons

It is now possible to add products to products, which is done by specifying
`+foo` at the end of a product description, where `foo` is the id of another
product. This can be used for surcharges and discounts, or for bundles of
products that can also be bought individually.

### Explicit contra accounts

By default, products sold via the `products` plugin, are accounted on the
`+sales/products` contra account. This can now be overridden by specifying
`@accountname` after the price in `revbank.products`. For example,
`1.00@+sales/products/specificcategory`. While this will mess up your tidy
columns, you may be able to get rid of a bunch of custom plugins now.

When the specified contra account is a regular account (does not start with `+`
or `-`), this works similar to the `market` plugin, but without any commission
for the organization.

## Pfand plugin: gone

The `pfand` plugin, that was originally written as a proof-of-concept demo, has
been removed without deprecation cycle. To my knowledge, nobody uses this
plugin. If you did use it, just grab the old version from git. Please let me
know about your usecase!

The introduction of beverage container deposits in The Netherlands has
triggered reevaluation, and several things about that plugin were wrong,
including the condescending comments that bottle deposits for small bottles
would be crazy or wouldn't make sense in a self-service environment. RevBank
was too limited to support it properly, but I think current RevBank fulfills
all requirements for making a better, proper pfand plugin.

## Perl warnings are now enabled for plugins

If you get Perl warnings from a plugin, and don't want to fix the issues with
the code (or disagree with the warning), just add "no warnings;" to the top of
the plugin file. However, the warnings are often indicative of suboptimal code
that is ground for improvement!

Most warnings will be about unitialized (undefined) values. Some guidance for
Perl newbies: you can test whether something is defined with `if
(defined($foo)) { ... }`, or provide a default value with `$foo // "example
default value"`.

# (2022-08-30) RevBank 3.5

RevBank now has a simple built-in text editor for products and market;
rationale in lib/RevBank/TextArea.pod.

This comes with a new dependency, the perl module Curses::UI (debian:
libcurses-ui-perl).

# (2022-06-11) RevBank 3.4

RevBank now has built-in hidden accounts and balanced transactions
(double-entry bookkeeping). These accounts will be made automatically, and
hidden from the user interface.

## Update external scripts

If you have scripts that parse `.revbank.log` or `revbank.products`, you may
want to ignore all accounts that start with `-` or `+`.

## User account names that are now invalid

In the hopefully very unlikely event that you have existing user accounts that
start with `-` or `+`, those will have to be renamed manually, as such accounts
are no longer accessible.

## Updating custom plugins (optional for now)

For your custom plugins, you may want to add `->add_contra` calls to every
`$cart->add` call that does not already have them. Unbalanced transactions will
probably be deprecated in a future version.

## New feature: cashbox tracking

The new `cash` plugin will display messages about how much the cash box should
hold, whenever someone withdraws or does a cash deposit. For that to make
sense, this requires the `deposit_methods` plugin to be enabled, and to have
a `"cash"` deposit method.

When adding the `cash` plugin in `revbank.plugins`, make sure it is listed
_before_ `stock` if you have that one too. And you probably want to enable
the `skim` plugin too, which introduces the (hidden) commands `skim` and
`unskim` which can be used to keep the cash box data synchronised when someone
(probably a board member) skims it.

# (2022-06-04) RevBank 3.3

Raw amounts without a command are no longer supported. There was already an
explicit command for unlisted products, `unlisted`, and for withdrawals there
is now the new command `withdraw`. An explanatory message guides users who
use the old style towards the new commands.

This change makes it possible for treasurers to more accurately deduce the
intention of a revbank transaction.

When upgrading, make sure the `unlisted` plugin is installed in
`revbank.plugins`. Without it, the instruction text presented when someone
enters an amount is wrong and the functionality for paying for unlisted
products is lost.

# (2021-12-02) RevBank 3.2

## Update your custom plugins!

Test your custom plugins. If they don't emit warnings about floating point
numbers, or if you don't care about warnings, then no changes are required.

RevBank no longer uses floating point numbers for amounts. Instead, there
are now RevBank::Amount objects, which internally store an integer number
of cents, but externally stringify to formatted numbers with 2 decimal places.

To create such an object, use `parse_amount` as per usual.

Formatting no longer requires `sprintf %.2f`, just use `%s` instead.

Using an amount as a floating point number will now emit warnings in some
cases, to alert you to the fact that this may result in rounding errors.
To convert an amount to a floating point number without a warning, use
`$amount->float`. To convert a floating point number to an amount without a
warning, use `RevBank::Amount->new_from_float($float)`.

Most hard-coded uses of floats are safe enough and transparently supported
through overloaded operators, but if there are more than 2 decimal places, the
operation will be disallowed.

# (2019-11-05) RevBank 3

The following features were removed:

- plugins `nyan` and `game`

    Please remove these from your `revbank.plugins` configuration file.

- creating new accounts with `deposit`

    Use `adduser` instead.

## Update your custom plugins!

### Method `$cart->is_multi_user`

Method has been removed.

### Method `$cart->delete($user, $index)`

Method has been removed.

Delete a specific entry, as returned by `$cart->entries`, instead.

### Hooks `add` and `added`

Use `add_entry` and `added_entry` instead, which gets a RevBank::Cart::Entry
object, instead.

Note that the new "entries", unlike old "items", can have a `quantity` other
than 1.

### Method `$cart->add(undef, ...)`

### Method `$cart->add($user, ...)`

The `add` method now always creates an entry from the perspective of the
current user, and returns a RevBank::Cart::Entry object to which "contras" can
be added with `add_contra`. The contras can be used for counteracting a value
with an operation on another account.

To upgrade a plugin that does a single `add` with `undef` as the first
argument, simply remove the `undef, `. When multiple items were added that
belong together, consider using `add_contra` for the subsequent lines; see the
`take` and `give` plugins for examples.

### Method `$cart->select_items`

Use `entries` instead, which takes the same kind of argument. Note that
entries work slightly differently: they can have a quantity and attached contra
entries. Attributes are now accessed through the `has_attribute` and
`attribute` methods, instead of directly manipulating the hash.
