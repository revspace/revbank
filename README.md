# NAME

revbank - Banking for hackerspace visitors

# ANNOUNCEMENTS

The following features were removed:

- plugins `nyan` and `game`

    Please remove these from your `revbank.plugins` configuration file.

- creating new accounts with <Cdeposit>

    Use `adduser` instead.

- Method `$cart->is_multi_user`
- Method `$cart->delete($user, $index)`

    Delete a specific entry, as returned by `$cart->entries`, instead.

The following will disappear in a future version:

## Hooks `add` and `added`

Use `add_entry` and `added_entry` instead, which gets a RevBank::Cart::Entry
object, instead.

Note that the new "entries", unlike old "items", can have a `quantity` other
than 1.

## Method `$cart->add(undef, ...)`

## Method `$cart->add($user, ...)`

The `add` method now always creates an entry from the perspective of the
current user, and returns a RevBank::Cart::Entry object to which "contras" can
be added with `add_contra`. The contras can be used for counteracting a value
with an operation on another account.

To upgrade a plugin that does a single `add` with `undef` as the first
argument, simply remove the `undef, `. When multiple items were added that
belong together, consider using `add_contra` for the subsequent lines; see the
`take` and `give` plugins for examples.

## Method `$cart->select_items`

Use `entries` instead, which takes the same kind of argument. Note that
entries work slightly differently: they can have a quantity and attached contra
entries. Attributes are now accessed through the `has_attribute` and
`attribute` methods, instead of directly manipulating the hash.

# DESCRIPTION

Maybe I'll write some documentation, but not now.

Shell-like invocation with `-c` is supported, sort of, but it has to be a
complete command. Currently, multiple commands are supported on the command
line (space separated), but that's an unintended feature...

# PLUGINS

Refer to [RevBank::Plugins](https://metacpan.org/pod/RevBank::Plugins) for documentation about writing plugins.

Plugins themselves may have some documentation in the respective plugin files.

Note that plugins that begin with `revspace_` are revspace specific hacks, and
were not written with reusability in mind. They will probably not work for your
setup.

# AUTHOR

Juerd Waalboer <#####@juerd.nl>

# LICENSE

Pick your favorite OSI license.
