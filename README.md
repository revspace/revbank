# NAME

revbank - Banking for hackerspace visitors

# ANNOUNCEMENTS

The following will disappear in a future version:

## Deprecated: `nyan`, `game`

These non-serious, non-banking plugins will be removed. Please remove them
from `revbank.plugins`.

## Deprecated: creating new accounts with `deposit`

For a while now, there has been a dedicated plugin, `adduser` to create new
accounts. The old way of creating new accounts (unknown input after a
`deposit` command was assumed to be the name of the a account) did not allow
for any input validation and would cause trouble if a user name already
existed.

Please add `adduser` to `revbank.plugins`.

# DESCRIPTION

Maybe I'll write some documentation, but not now.

Shell-like invocation with `-c` is supported, sort of, but it has to be a
complete command. Currently, multiple commands are supported on the command
line (space separated), but that's an unintended feature...

# PLUGINS

Refer to [RevBank::Plugins](https://metacpan.org/pod/RevBank::Plugins) for
documentation about writing plugins.

Plugins themselves may have some documentation in the respective plugin files.

Note that plugins that begin with `revspace_` are revspace specific hacks, and
were not written with reusability in mind. They will probably not work for your
setup.

# AUTHOR

Juerd Waalboer <#####@juerd.nl>

# LICENSE

Pick your favorite OSI license.
