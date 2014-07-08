package TOC;
use strict;

BEGIN {
    our %doc;
}

sub AddSection
{
    my $self = shift;
    my %args = (docEnv => undef,
                sectionType => 0,
                sectionTag => undef,
                sectionTagPrefix => undef,
                @_);

    die unless $args{docEnv};

    die unless $args{docEnv}->{sourceFile};

    return undef unless $TOC::doc{$args{docEnv}->{sourceFile}};

    my $toc = $TOC::doc{$args{docEnv}->{sourceFile}};

    if ($args{sectionType}+1 > scalar(@{$toc->{counter}})) {
        while ($args{sectionType}+1 > scalar(@{$toc->{counter}})) {
            push(@{$toc->{counter}}, 1);
        }
    } else {
        ++${$toc->{counter}}[$args{sectionType}];
    }
    while ($args{sectionType}+1 < scalar(@{$toc->{counter}})) {
        pop(@{$toc->{counter}});
    }

    my $tag = "toc" . join(".", @{$toc->{counter}});
    push(@{$toc->{sectionTags}}, $tag);
    push(@{$toc->{sectionTypes}}, $args{sectionType});
    push(@{$toc->{sections}}, $args{sectionTag});
    return $tag;
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {docEnv => undef,
                 maxTocLevel => 1,

                 css_class => undef,

                 sections => [],
                 sectionTags => [],
                 sectionTypes => [],
                 counter => [],
                 @_};
    bless ($self, $class);
    die unless $self->{docEnv};

    $TOC::doc{$self->{docEnv}->{sourceFile}} = $self;

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                tocTitle => "Content",
                maxTocLevel => $self->{maxTocLevel},
                @_);

    die unless $args{html};

    $args{html}->addLine(line => "<table id=\"toc\" class=\"toc\">");
    $args{html}->addLine(line => "<tr><td>");
    $args{html}->addLine(line => "<div id=\"toctext\"><h4 class=\"toc\">".
                                 "$args{tocTitle}".
                                 "</h4></div>");
    $args{html}->addLine(line => "<ul class=\"sections\">");

    my $currentSectionLevel = 0;
    for (my $i=0; $i < scalar(@{$self->{sectionTags}}); ++$i) {
        my $section = ${$self->{sections}}[$i];
        my $tag = ${$self->{sectionTags}}[$i];
        my $sectionLevel = ${$self->{sectionTypes}}[$i];

        next if $sectionLevel >= $self->{maxTocLevel};

        while ($currentSectionLevel < $sectionLevel) {
            ++$currentSectionLevel;
            my $sub = "sub" x $currentSectionLevel;
            $args{html}->addLine(line => "<li class=\"${sub}sectionitem\">");
            $args{html}->addLine(line => "<ul class=\"${sub}sections\">");
        }
        while ($currentSectionLevel > $sectionLevel) {
            --$currentSectionLevel;
            $args{html}->addLine(line => "</ul>");
            $args{html}->addLine(line => "</li>");
        }
        my $sub = "sub" x $currentSectionLevel;
        $args{html}->addLine(line => "<li class=\"${sub}section\">" .
                                "<a href=\"#$tag\" class=\"toc\">$section</a>" .
                                "</li>");
    }

    $args{html}->addLine(line => "</ul>");
    $args{html}->addLine(line => "</td></tr>");
    $args{html}->addLine(line => "</table>");
}


1;
