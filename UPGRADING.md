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

There's new syntax for `revbank.products`: addons. Check that your lines don't
have `+foo` at the end, where `foo` can be anything.

Also check that you don't have any product ids that start with `+`; those can
no longer be entered as this syntax now has special semantics.

So these don't work as before:

    example_id      1.00  Example product +something
    +something      1.00  Product id that starts with plus
    example,+alias  1.00  Alias that starts with plus

These will keep working as they were:

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
