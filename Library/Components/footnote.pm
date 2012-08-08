package Footnote;
use strict;

sub SingleQuotes
{
    return undef;
}

sub DoubleQuotes
{
    return undef;
}

sub LeftQuote
{
    return "^[";
}

sub RightQuote
{
    return "]";
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {string           => undef,

                 isDefinitionList => undef,
                 definitionList   => [],

                 css_class        => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{string} || $self->{isDefinitionList};

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    if ($self->{isDefinitionList}) {
        $args{html}->addLine(line => "<ul class=\"footnote\">");
        for my $item (@{$self->{definitionList}}) {
            my $link = "footnote" . $item->{key};
            my $openTag  = "<sup class=\"footnote\">" .
                           "<a class=\"footnote\" name=\"$link\">";
            my $closeTag = "</a></sup>";
            $args{html}->append(line => "<li class=\"footnote\">");
            $args{html}->append(line => $openTag .
                                        $item->{key} .
                                        $closeTag);
            for my $value (@{$item->{value}}) {
                $value->html(html => $args{html});
            }
            $args{html}->append(line => "</li>");
        }
        $args{html}->addLine(line => "</ul>");
    } else {
        my $link = "#footnote" . $self->{string}->{value};
        my $openTag  = "<sup class=\"footnote\">" .
                       "<a class=\"footnote\" href=\"$link\">";
        my $closeTag = "</a></sup>";
        $args{html}->append(line => $openTag .
                                    $self->{string}->{value} .
                                    $closeTag);
    }
}

sub plain
{
    my $self = shift;
    my %args = (@_);

    return $self->{string}->{value};
}

1;
