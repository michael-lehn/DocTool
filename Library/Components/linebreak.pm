package Linebreak;
use strict;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {@_};
    bless ($self, $class);

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    $args{html}->append(line => "<br>");
}

1;