package RevBank::Plugin;
use strict;

sub new {
    my ($class) = @_;
    return bless { }, $class;
}


1;

__END__

=head1 NAME

RevBank::Plugin - Base class for RevBank plugins

=head1 DESCRIPTION

Documentation on writing plugins is at L<RevBank::Plugins>.
