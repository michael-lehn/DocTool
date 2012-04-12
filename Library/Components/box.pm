package Box;
use strict;
use String;

sub Keyword
{
    return "BOX";
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {lines => undef,
                 optionString => undef,
                 docEnv => undef,
                 content => undef,
                 options => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{docEnv};

    my $linebuffer = Linebuffer->new(buffer => $self->{lines},
                                     docEnv => $self->{docEnv});
    $self->{content} = Parse->new(linebuffer => $linebuffer);

    $self->{options} = { class => "note",
                         Options->Split(string => $self->{optionString})
                       };
    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    my $css = $self->{options}->{class};
    $args{html}->addLine(line => "<div class=\"box $css box_container\">");
    if ($self->{options}->{title}) {
        $args{html}->addLine(line => "<div class=\"box box_title\">");
        $args{html}->addLine(line => $self->{options}->{title});
        $args{html}->addLine(line => "</div><!-- class=\"box box_title\" -->");
    }
    $args{html}->addLine(line => "<div class=\"box box_content\">");
    $self->{content}->html(html => $args{html});
    $args{html}->addLine(line => "</div><!-- class=\"box box_content\" -->");
    $args{html}->addLine(line => "</div><!-- class=\"box box_container\" -->");
}


1;
