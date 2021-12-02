# revbank - Banking for hackerspace visitors

## Upgrading

When upgrading from a previous version, please refer to the file [UPGRADING.md](UPGRADING.md)
because there might be incompatible changes that require your attention.

## Installing

1. Install the Perl module Term::ReadLine::Gnu

```
Debian:  apt install libterm-readline-gnu-perl
Generic: cpan Term::ReadLine::Gnu
```

2. Clone the repository, run revbank :)

## Using revbank

Type `help`.

Even more helpful text is available on the [the RevBank page on the RevSpace wiki](https://revspace.nl/RevBank).

## Writing plugins

Read [RevBank::Plugins](lib/RevBank/Plugins.pod) and [RevBank::Amount](lib/RevBank/Amount.pod).

## Exiting revbank

Exiting is not supported because it's desigend to run continuously. But if you
run it from a shell, you can probably stop it using ctrl+Z and then kill the
process (e.g. `kill %1`). RevBank does not keep any files open, so it's safe
to kill when idle.
