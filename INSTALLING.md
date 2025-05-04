## Installing RevBank

RevBank will work on almost any sufficiently recent Linux or similar operating
system, and should at least work on the current Debian `stable` or `oldstable`
releases.


1. Install the dependencies:

Most major Linux distributions come with `perl` preinstalled.

RevBank requires a few additional Perl modules:

```
Debian:  apt install libterm-readline-gnu-perl libcurses-ui-perl

Generic: cpan Term::ReadLine::Gnu Curses::UI
```

2. Clone the repository, run `./revbank` :)

## Configuring RevBank

**RevBank just works out of the box** if you're in a hurry, but there's a lot you
could customize.

`revbank` reads and writes files in the _data directory_, which is
automatically created as `.revbank` in your home directory when you first run
revbank. (A different path can be configured with the environment variable
`REVBANK_DATADIR` or `--datadir` on the command line.)

For examples, see `README.md` in the `data` directory of this git repository.

### Pick a transaction ID scheme

By default, RevBank will use positive integer transaction IDs, starting with 1.
It is possible to have different transaction IDs if you like, for example if
you want to have a fixed length and a prefix.

You can use any alphanumeric string that Perl can increment with the ++ operator:

```sh
# Default
echo 1 > ~/.revbank/nextid
# or
echo 00001 > ~/.revbank/nextid
# or
echo AAAA > ~/.revbank/nextid
# or
echo XZ0000 > ~/.revbank/nextid
```

This should be done before executing the first transaction. RevBank will
increment the number.

Considerations:

- After `EXAMPLE9` comes `EXAMPLF0`, so when using a prefix, you also want
  sufficient leading zeros.

- Letters in transaction IDs are supported, but may not be compatible with
  local laws or external accounting software.

- If you do wish to start a new sequence in an existing RevBank installation,
  you should clear `~/.revbank/undo` first if there is any chance that the
  sequences will overlap.

### Other configuration

- `plugins`: enable or disable plugins here.
- `accounts`: if you're migrating from another system, you can add the
  existing account balances here. Only the first two columns are mandatory
  (account name and balance). Editing the accounts file when revbank is in
  active use is not recommended because you might overwrite the effect of the
  latest transactions, but you can maybe get away with it if you're fast
  enough.
- `products`: list your products here; the first column is a comma
  separated (no space after the comma!) list of product codes. Only the
  description makes it into the logs so make it sufficiently unique.
- `plugins/deposit_methods`: if you want to enable this plugin (which is highly
  recommended!), at least change the bank account number. When customizing
  plugins, you can either copy the file and use your own, or edit the existing
  file and deal with merge conflicts later. Either way you'll have to pay
  attention to changes when upgrading.

After changing the `plugins` file or any of the actual plugin files, you'll
need to restart `revbank`. This is done with the `restart` command, unless the
corresponding plugin was disabled. No restart is required after editing
`products`, `market`, or `accounts`.

If your terminal is unable to beep, e.g. if it's Linux console on a Raspberry
Pi, copy the `beep_terminal` plugin to a new file, and figure out another way
to play a sound or make a light flash. This is optional, but in general it's
useful to have something that alerts users to the mistakes they make. An
audible bell works better than a visual effect, but why not both?

### Cash box

If you want RevBank to indicate how much money it thinks the cash box should
contain after every cash transaction, you'll probably want to enable the
plugins `deposit_methods`, `cash`, and `skim`.

## Sysadmin considerations

- Consider high-frequency (e.g. once per hour) remote backups of the data
  directory, and that synchronization is not the same as a real backup. In
  fact, go configure that right now :).

- You may want to enable the `git` plugin to let git keep track of the data
  directory; note that this excludes the log files. If you want to push this to
  a remote repo, do so in a cron job or systemd timer, or similar.

- RevBank is insecure by design and fully based on the honor system. Might as
  well give people real shell access on a spare tty, or via ssh. That can be
  quite useful and with frequent backups it shouldn't be too scary.

- Many filesystems support append only modes. For example, you could do `chattr
  +a` as root, after which a regular user can't modify existing log lines
  anymore.

- With high traffic, at some point certain RevBank operations can become
  sluggish because they literally read from the log file. Simply rotating the
  log file once a year, fully works around this issue. This is also useful for
  the treasurer/accountant, especially if you keep a copy of
  `~/.revbank/accounts` from the same point in time, and that point of time is
  between the last transaction of the year, and the next transaction of the next
  year.

## Using RevBank

First steps: try `help`. Then try `adduser` and `deposit`.
