# revbank - Banking for hackerspace visitors

## Installing RevBank

For new installations, refer to [INSTALLING.md](INSTALLING.md).

## Upgrading RevBank

When upgrading from a previous version, please refer to the file
[UPGRADING.md](UPGRADING.md) because there might be incompatible changes that
require your attention.

## Using RevBank (for end users)

Type `help`.

### Exiting revbank

Exiting is not supported because it's designed to run continuously on its main
terminal. But if you run it from a shell, you can probably stop it using ctrl+Z
and then kill the process (e.g. `kill %1`). RevBank does not keep any files
open, so it's safe to kill when idle.

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
- [RevBank::Products](lib/RevBank/Products.pod) - revbank.products file format
- [RevBank::TextEditor](lib/RevBank/TextEditor.pod) - internal pager and editor
- [RevBank::Users](lib/RevBank/Users.pod) - user accounts and special accounts

The plugins are mostly undocumented, but some have useful hints in the source
files, and some have actual documentation:

- [statiegeld](plugins/statiegeld.pod)
- [statiegeld\_tokens](plugins/statiegeld_tokens.pod)
- [vat](plugins/vat.pod)

> Note: internal links between POD files are all broken in GitHub's rendering,
> because GitHub wrongly assumes that every Perl package lives on CPAN.

