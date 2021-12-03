package RevBank::Plugin;

use v5.28;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

require RevBank::Global;

sub new($class) {
    return bless { }, $class;
}
sub command($self, $cart, $command, @) {
    return RevBank::Global::NEXT();
}


1;

__END__

=head1 NAME

RevBank::Plugin - Base class for RevBank plugins

=head1 DESCRIPTION

Documentation on writing plugins is at L<RevBank::Plugins>.
