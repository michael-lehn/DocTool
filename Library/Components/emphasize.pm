package Emphasize;
use strict;

our %SingleQuotes = (qw(_) => qw(italic),
                     qw(*) => qw(bold),
                     qw(`) => qw(verbatim),
                     qw(") => qw(doubleQuoted));

our %DoubleQuotes = (qw(') => qw(verbatim));

sub SingleQuotes
{
    return join("", keys %Emphasize::SingleQuotes);
}

sub DoubleQuotes
{
    return join("", keys %Emphasize::DoubleQuotes);
}

sub LeftQuote
{
    return undef;
}

sub RightQuote
{
    return undef;
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {string => undef,
                 singleQuote => undef,
                 doubleQuote => undef,

                 bold => undef,
                 italic => undef,
                 verbatim => undef,

                 contains => undef,

                 css_class => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{string};

    if ($self->{singleQuote}) {
        die unless $Emphasize::SingleQuotes{$self->{singleQuote}};
        $self->{$Emphasize::SingleQuotes{$self->{singleQuote}}} = 1;
    }
    if ($self->{doubleQuote}) {
        die unless $Emphasize::DoubleQuotes{$self->{doubleQuote}};
        $self->{$Emphasize::DoubleQuotes{$self->{doubleQuote}}} = 1;
    }

    unless ($self->{verbatim}) {
        $self->{contains} = String->Parse(string => $self->{string});
    } else {
        $self->{contains} = [ $self->{string} ];
    }

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    my $openTag;
    my $closeTag;

    if ($self->{bold}) {
        $openTag = "<b>";
        $closeTag = "</b>";
    } elsif ($self->{underline}) {
        $openTag = "<u>";
        $closeTag = "</u>";
    } elsif ($self->{italic}) {
        $openTag = "<i>";
        $closeTag = "</i>";
    } elsif ($self->{doubleQuoted}) {
        $openTag = "&#8220;";
        $closeTag = "&#8221";
    } elsif ($self->{verbatim}) {
        $openTag = "<tt>";
        $closeTag = "</tt>";
    }

    $args{html}->append(line => "$openTag");
    for my $component (@{$self->{contains}}) {
        $component->html(html => $args{html});
    }
    $args{html}->append(line => "$closeTag");
}

sub plain
{
    my $self = shift;
    my %args = (@_);

    my $plain  = "";
    for my $component (@{$self->{contains}}) {
        $plain = $plain . $component->plain();
    }
    return $plain;
}

1;
