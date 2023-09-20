# revbank - Banking for hackerspace visitors

## Using RevBank (for end users)

Type `help`.

More detailed help is available in Dutch on the [the RevBank page on the
RevSpace wiki](https://revspace.nl/RevBank).

### Exiting revbank

Exiting is not supported because it's designed to run continuously on its main
terminal. But if you run it from a shell, you can probably stop it using ctrl+Z
and then kill the process (e.g. `kill %1`). RevBank does not keep any files
open, so it's safe to kill when idle.

## Upgrading RevBank

When upgrading from a previous version, please refer to the file
[UPGRADING.md](UPGRADING.md) because there might be incompatible changes that
require your attention.

In general, upgrading is done by committing any changed files and then doing a
`git pull`.

## Installing RevBank

1. Install the dependencies:

```
Debian:  apt install libterm-readline-gnu-perl libcurses-ui-perl
Generic: cpan Term::ReadLine::Gnu Curses::UI
```

2. Clone the repository, run `./revbank` :)

## Configuring RevBank

`revbank` uses data files from the _working directory_ from which it runs. You
can use that to your advantage, if you don't want to change anything in your
git working tree - in that case, copy `revbank.*` to the intended working
directory, and symlink `plugins`. But you can also just change the files and
deal with merge conflicts later, if you prefer.

**RevBank just works out of the box** if you're in a hurry, but there's a lot you
could customize.

### Pick a transaction ID scheme

If you skip this step, RevBank will use a large timestamp as a safe fallback.

You can use any string that Perl can increment with the ++ operator:

```sh
# Simple, recommended:
echo 1 > .revbank.nextid
# or
echo 00001 > .revbank.nextid
# or
echo AAAA > .revbank.nextid
```

This should be done only once. RevBank will increment the number. If you do
wish to start a new sequence, you should clear `.revbank.undo` first if there
is any chance that the sequences will overlap.

### Other configuration

- `revbank.plugins`: enable or disable plugins here.
- `revbank.accounts`: if you're migrating from another system, you can add the
  existing account balances here. Only the first two columns are mandatory
  (account name and balance). Editing the accounts file when revbank is in
  active use is not recommended because you might overwrite the effect of the
  latest transactions, but you can maybe get away with it if you're fast
  enough.
- `revbank.products`: list your products here; the first column is a comma
  separated (no space after the comma!) list of product codes. Only the
  description makes it into the logs so make it sufficiently unique.
- `plugins/deposit_methods`: if you want to enable this plugin (which is highly
  recommended!), at least change the bank account number. When customizing
  plugins, you can either copy the file and use your own, or edit the existing
  file and deal with merge conflicts later. Either way you'll have to pay
  attention to changes when upgrading.

After changing `revbank.plugins` or any of the actual plugin files, you'll need
to restart `revbank`. The easiest way to do that is ctrl+D. No restart is
required after editing `revbank.products`, `revbank.market`, or
`revbank.accounts`.

If your terminal is unable to beep, e.g. if it's Linux console on a Raspberry
Pi, copy the `beep_terminal` plugin to a new file, and figure out another way
to play a sound or make a light flash. This is optional, but in general it's
useful to have something that alerts users to the mistakes they make. An
audible bell works better than a visual effect, but why not both?

### Cash box

If you want RevBank to indicate how much money it thinks the cash box should
contain after every cash transaction, you'll probably want to enable the
plugins `deposit_methods`, `cash`, and `skim`.

## Documentation

End-user documentation is provided through the `help` command. For RevSpace
visitors, some additional end-user documentation is available in Dutch at
https://revspace.nl/RevBank.

RevBank can be used without RTFM, but some documentation is provided to
describe the inner workings in more detail:

- [RevBank](lib/RevBank.pod) - technical overview
- [RevBank::Amount](lib/RevBank/Amount.pod) - fixed decimal numbers
- [RevBank::FileIO](lib/RevBank/FileIO.pod) - reading and writing files
- [RevBank::Global](lib/RevBank/Global.pod) - constants and utility functions
- [RevBank::Plugins](lib/RevBank/Plugins.pod) - writing plugins
- [RevBank::TextEditor](lib/RevBank/TextEditor.pod) - internal pager and editor

The plugins are mostly undocumented, but some have useful hints in the source
files, and some have actual documentation:

- [products](plugins/products.pod)
- [statiegeld](plugins/statiegeld.pod)
- [statiegeld\_tokens](plugins/statiegeld_tokens.pod)
- [vat](plugins/vat.pod)

> Note: internal links between POD files are all broken in GitHub's rendering,
> because GitHub wrongly assumes that every Perl package lives on CPAN.

