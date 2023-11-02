package RevBank::Plugin;

use v5.28;
use warnings;
use experimental 'signatures';  # stable since v5.36
use attributes;

require RevBank::Global;

sub new($class) {
    return bless { }, $class;
}

sub command($self, $cart, $command, @) {
    return RevBank::Global::NEXT();
}

sub Tab($self, $method) {
    my %completions;

    my $attr = attributes::get(
        ref $method ? $method : $self->can($method)
    ) or return;

    my ($tab) = $attr =~ /Tab \( (.*?) \)/x;
    for my $keyword (split /\s*,\s*/, $tab) {
        if ($keyword =~ /^&(.*)/) {
            my $method = $1;
            @completions{ $self->$method } = ();
        } else {
            $completions{ $keyword }++;
        }
    }

    if (delete $completions{USERS}) {
        for my $name (RevBank::Users::names()) {
            next if RevBank::Users::is_hidden($name);

            $completions{ $name }++;
            $completions{ $1 }++ if $name =~ /^\*(.*)/;
        }
    }

    return keys %completions;
}

1;

__END__

=head1 NAME

RevBank::Plugin - Base class for RevBank plugins

=head1 DESCRIPTION

Documentation on writing plugins is at L<RevBank::Plugins>.
