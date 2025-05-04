This directory contains example data files.

By default, RevBank puts its data files in `~/.revbank`. It is possible to
configure another directory with the environment variable `REVBANK_DATADIR` or
`--datadir` on the command line (the latter overrules the former) if both are
present.

If the directory does not exist, it will be created and populated with a copy
of the example `plugins` file, the example `products` file, and an empty
`accounts` file.

It is recommended to keep your data files in a separate git repository; the
`git` plugin automates that. Note that git is not a proper backup tool, you
should also have actual backups.

It is possible, but not recommended, to use this directory within the code
repository.
