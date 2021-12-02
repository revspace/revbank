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
