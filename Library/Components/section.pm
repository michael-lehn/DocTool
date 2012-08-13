package Section;
use strict;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {string => undef,

                 contains => undef,
                 sectionTag => undef,
                 char => undef,
                 marks => [],

                 css_class => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{string};

    $self->{contains} = String->Parse(string => $self->{string});

    unless ($self->{sectionTag}) {
        $self->{sectionTag} = "";
        for my $component (@{$self->{contains}}) {
            $self->{sectionTag} = $self->{sectionTag}
                                . $component->plain();
        }
    }

    if ($self->{char} eq "=") {
        $self->{sectionType} = 0;
    } elsif ($self->{char} eq "-") {
        $self->{sectionType} = 1;
    } elsif ($self->{char} eq "~") {
        $self->{sectionType} = 2;
    }

    my $tocMark = TOC->AddSection(docEnv => $self->{string}->{docEnv},
                                  sectionType => $self->{sectionType},
                                  sectionTag => $self->{sectionTag});
    if ($tocMark) {
        push(@{$self->{marks}}, $tocMark);
    }
    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    my $level = $self->{sectionType} + 2;
    my $tag = "h$level";

    $args{html}->addLine();
    $args{html}->addLine();
    $args{html}->addLine(line => "<$tag class=\"doc\">");

    for my $mark (@{$self->{marks}}) {
        $args{html}->addLine(line => "<a name=\"$mark\"></a>");
    }

    $args{html}->incrementIndentLevel();
    for my $component (@{$self->{contains}}) {
        $component->html(html => $args{html});
    }
    $args{html}->decreaseIndentLevel();

    $args{html}->addLine(line => "</$tag>");
    $args{html}->addLine();

#   register that we just formated the title
    $args{html}->{currentSection} = "SECTION $level";
}

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    my $chars = "[=~-]";
    my $docEnv = $args{linebuffer}->{docEnv};

    # for a section at least one more line is required
    return undef
        if $args{linebuffer}->end(offset => 1);

    # second line has to be a sequence of $chars
    return undef
        unless $args{linebuffer}->line(offset => 1)
               =~ /^(\s*)(${chars})(${chars}*)\s*$/;

    # indent length
    my $l = length($1);
    # length of $char sequence
    my $L = length($3)+1;

    my $char = $2;
    return undef
        unless $3 =~ /^$char*/;

    # extract section name
    return undef
        unless 
            $args{linebuffer}->line(offset => 0) =~ /^\s{$l,$l}(.{$L,$L})(.*)/;

    my ($sectionName, $mark) = ($1, $2);

    my @marks;
    while ($mark =~ s/\[\[(.*?)\]\]//) {
        push(@marks, $1);
    }

    # update linebuffer
    $args{linebuffer}->moveLineCursor(offset => 2);

    # create title component and append it
    return Section->new(string => String->new(value => $sectionName,
                                              docEnv => $docEnv),
                        marks => [@marks],
                        char => $char);
}

1;
