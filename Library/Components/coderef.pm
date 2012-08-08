package CodeRef;
use strict;
use String;
use Options;
use DocUtils;
use CxxIndex;

sub Keyword
{
    return "CODEREF";
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {lines        => undef,
                 description  => undef,
                 docEnv       => undef,
                 optionString => "",

                 codeId       => undef,

                 type         => "cc",
                 html         => undef,
                 @_};
    bless ($self, $class);

#
#   Set the codeId
#
    $self->{codeId} = $self->{optionString};
    $self->{codeId} =~ s/^(.*)#c:/c:/;
    $self->{attribute} = $1;

    my $entry = CxxIndex->GetId(id => $self->{codeId});

#
#   Check if this is a valid CODEREF
#
    unless ($entry) {
        if ($self->{attribute} && ($self->{attribute} =~ "O")) {
            printf STDERR "[ERROR] CODEREF with id '$self->{codeId}' is ".
                          "obsolete.\n";
        } else {
            printf STDERR "[ERROR] Unknown coderef id '$self->{codeId}'.\n";
        }
        die;
    }

#
#   Cleanup the referenced codeline, e.g. trimm blanks, ...
#
    my $offset = length($self->{lines}->[0]);
    for (my $line=0; $line<=$#{$self->{lines}}; ++$line) {
        $self->{lines}->[$line] =~ s/\s*$//;
        $self->{lines}->[$line] =~ /^(\s*)/;
        if (length($1)<$offset) {
            $offset = length($1);
        }
    }
    if ($offset>2) {
        $offset = 2;
    }
    for (my $line=0; $line<=$#{$self->{lines}}; ++$line) {
        $self->{lines}->[$line] = substr($self->{lines}->[$line], $offset);
    }


    die unless $self->{docEnv};

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    $self->convert(html => $args{html});
    for my $line (@{$self->{html}}) {
        $args{html}->addLine(line => $line, preserveIndent => 1);
    }
}

sub convert
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    my @codelines = Convert->CodeBlock(codelinesRef => $self->{lines},
                                       fileExtension => $self->{type},
                                       linenumbers => $self->{linenumbers});

    my $first = shift(@codelines);
    my $last  = pop(@codelines);

#
#   This is a documentation of 'id'.  Get all info about 'id'.
#
    my $entry = CxxIndex->GetId(id => $self->{codeId});

    unless ($entry) {
        # This already should have had happened in 'new'
        die;
    }

    my $file = $entry->{file};
    my $docId = "file:$entry->{headerfile}";

    $entry->{headerfile_range} =~ /^(\d+):/;
    my $link = Html->MakeLink(fromDocEnv => $args{html}->{docEnv},
                              toDocEnv => $docId,
                              mark => $1);

    $args{html}->addLine(line => "<a name=\"$self->{codeId}\"> </a>\n");
    $args{html}->addLine(line => "<div class=\"coderef_outer\">\n");
    $args{html}->addLine(line => "<div class=\"coderef\">\n");
    $args{html}->addLine(line => $first);
    $args{html}->addLine(line => "<a class=\"coderef\" href=\"$link\">\n");
    $args{html}->addLine(linesRef => \@codelines);
    $args{html}->addLine(line => "</a>\n");
    $args{html}->addLine(line => $last);
    $args{html}->addLine(line => "</div><!-- coderef-->\n");
    if ($self->{description}) {
        $args{html}->addLine(line => "<div class=\"code_description\">\n");
        $self->{description}->html(html => $args{html});
        $args{html}->addLine(line => "</div>\n");

    }
    $args{html}->addLine(line => "</div><!-- coderef_outer-->\n");

#
#   Register that this 'docId' is a documentation of 'id'
#
    CxxIndex->UpdateHeaderIndex(docEnv => $args{html}->{docEnv},
                                id     => $self->{codeId});
}

sub Snippet2CodeRef
{
    my $class = shift;
    my %args = (snippet   => undef,
                id        => undef,
                attribute => undef,
                @_);

    my @lines;

    die unless $args{snippet};
    die unless $args{id};

    if ($args{attribute}) {
        $args{id} = $args{attribute} . "#" . $args{id};
    }

    my $width = 75;
    foreach my $line (@{$args{snippet}}) {
        if (length($line)+4>$width) {
            $width = length($line) + 4;
        }
    }

    my $title = "*--[CODEREF]";

    push(@lines, $title . "-" x ($width-length($title)+1) . "*");
    push(@lines, "|" . " " x $width . "|");

    foreach my $line (@{$args{snippet}}) {
        push(@lines, "|  " . $line . " " x ($width-length($line)-2) . "|");
    }

    push(@lines, "|" . " " x $width . "|");
    push(@lines, "*" . "-" x $width . "*");


    my $id = $args{id};

    my $idWidth = length($id);
    if ($idWidth>2*$width/3) {
        $idWidth = int(2*$width/3);
    }

    do {
        my $string = substr($id, 0, $idWidth);
        if (length($string)<$idWidth) {
            $string .= " " x ($idWidth-length($string));
        }

        $string = " " x ($width-$idWidth) . "[$string]";
        push(@lines, $string);

        if (length($id)>$idWidth) {
            $id = substr($id, $idWidth);
        } else {
            $id = undef;
        }

    } while ($id);

    return \@lines;
}

sub CodeRef2Snippet
{
    my $class = shift;
    my %args = (coderef => undef,
                @_);

    die unless $args{coderef}->[-1] =~ /^\s*\[.*\]\s*$/;
    my $id = "";
    while ($args{coderef}->[-1] =~ /^\s*\[(.+?)\]\s*$/) {
        $id = "$1" . $id;
        pop(@{$args{coderef}});
    }
    $id =~ s/\s*$//;

    die unless $args{coderef}->[0] =~ /^\s*\*--\[CODEREF\]-*\*\s*$/;
    die unless $args{coderef}->[-1] =~ /^\s*\*-*\*\s*$/;

#   remove attribute
    my $attribute = undef;
    if ($id =~ s/^(.*)#c:/c:/) {
        $attribute = $1;
    }

    my $l = length($args{coderef}->[0]);

    shift(@{$args{coderef}});
    pop(@{$args{coderef}});
    pop(@{$args{coderef}});

    for (my $line=0; $line<=$#{$args{coderef}}; ++$line) {
        die unless $args{coderef}->[$line] =~ /^(\s*\|\s*)/;
        if (length($1)<$l) {
            $l = length($1);
        }
    }

    my $result = {snippet   => [],
                  id        => $id,
                  attribute => $attribute};

    for (my $i=0; $i<=$#{$args{coderef}}; ++$i) {
        my $line = substr($args{coderef}->[$i], $l);
        $line =~ s/\s*$//;
        $line =~ s/\|$//;
        $line =~ s/\s*$//;

        if ($i==0 || $i==$#{$args{coderef}}) {
            next if $line =~ /^\s*$/;
        }

        push(@{$result->{snippet}}, $line);
    }
    return $result;
}


1;
