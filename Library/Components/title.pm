package Title;
use TOC;
use strict;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {string => undef,

                 contains => undef,
                 toc => undef,

                 css_class => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{string};

    $self->{contains} = String->Parse(string => $self->{string});

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    my $css = "class=\"doc\"";

    $args{html}->addLine();

    if ($self->{toc}) {
        $self->{toc}->html(html => $args{html});
    }

    $args{html}->addLine(line => "<h1 $css>");

    $args{html}->incrementIndentLevel();
    for my $component (@{$self->{contains}}) {
        $component->html(html => $args{html});
    }
    $args{html}->decreaseIndentLevel();

    $args{html}->addLine(line => "</h1>");
    $args{html}->addLine();
}

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    die unless $args{linebuffer};
    my $docEnv = $args{linebuffer}->{docEnv};

    my $char = "=";

    # for a title at least two more lines are required
    return undef
        if $args{linebuffer}->end(offset => 2);

    # a title starts with a sequence of $char
    return undef
        unless $args{linebuffer}->line() =~ /^(\s*)(${char}+)\s*$/;

    # indent length
    my $l = length($1);
    # length of $char sequence
    my $L = length($2);

    # a title ends with a sequence of $char of same length
    return undef 
        unless
            $args{linebuffer}->line(offset => 2) =~ /^\s{$l,$l}${char}{$L,$L}\s*$/;

    # extract the title between the sequences of $char
    return undef
        unless 
            $args{linebuffer}->line(offset => 1) =~ /^\s{$l,$l}(.{$L,$L})(.*)$/;

    my ($title, $toc) = ($1, $2);
    if ($toc =~ /\[TOC\]/) {
        $toc = TOC->new(docEnv => $docEnv);
    } else {
        $toc = undef;
    }

    # update linebuffer
    $args{linebuffer}->moveLineCursor(offset => 3);

    # create title component and return it
    return Title->new(string => String->new(value => $title, docEnv => $docEnv),
                      toc => $toc);
}

1;
