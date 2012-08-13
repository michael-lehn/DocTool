package Paragraph;
use strict;
use Linebreak;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {contains => undef,
                 css_class => undef,
                 @_};

    bless ($self, $class);
    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    my $css = "";
    if ($args{html}->{paramlist}) {
        $css = "class=\"paramlist\"";
    }

    $args{html}->addLine(line => "<p $css>");

    $args{html}->incrementIndentLevel();
    $args{html}->newLine();
    for my $component (@{$self->{contains}}) {
        $component->html(html => $args{html});
    }
    $args{html}->decreaseIndentLevel();
    $args{html}->append(line => "\n");
    $args{html}->newLine();
    $args{html}->append(line => "</p>");
}

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    return undef unless $args{linebuffer}->line() =~ /^(\s*)\S.*$/;
    my $l = length($1);

    my @content;
    my $string = "";
    while (! $args{linebuffer}->end()) {
        last unless $args{linebuffer}->line() =~ /^\s{$l,$l}(\S.*)$/;

        my $line = $1;
#
#       Hack: Stop if this is the start of a new ParamList
#
        last if $line =~ /\s{4,}\S/;

        $string = $string . " " . $line;

        if ($string =~ s/\s\+\s*$//) {
            my $s = String->new(value => $string,
                                docEnv => $args{linebuffer}->{docEnv});
            push(@content, @{String->Parse(string => $s)});
            push(@content, Linebreak->new());
            $string = "";
        }

        $args{linebuffer}->moveLineCursor(offset => 1);
    }
    my $s = String->new(value => $string,
                        docEnv => $args{linebuffer}->{docEnv});
    push(@content, @{String->Parse(string => $s)});

    return Paragraph->new(contains => \@content);
}

1;
