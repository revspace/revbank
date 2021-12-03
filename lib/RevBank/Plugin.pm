package RevBank::Plugin;
use strict;
require RevBank::Global;

sub new {
    my ($class) = @_;
    return bless { }, $class;
}
sub command {
    return RevBank::Global::NEXT();
}


1;

__END__

=head1 NAME

RevBank::Plugin - Base class for RevBank plugins

=head1 DESCRIPTION

Documentation on writing plugins is at L<RevBank::Plugins>.
