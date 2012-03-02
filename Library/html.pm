package Html;
use strict;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {linebuffer => [],
                 adt => undef,
                 docEnv => undef,
                 indentLevel => 0,
                 @_};
    bless ($self, $class);

    die unless $self->{adt};

    $self->{adt}->html(html => $self);

    return $self;
}

sub content
{
    my $self = shift;
    return @{$self->{linebuffer}};
}

sub incrementIndentLevel
{
    my $self = shift;
    ++$self->{indentLevel};
}

sub decreaseIndentLevel
{
    my $self = shift;
    --$self->{indentLevel};
}

sub _indentString
{
    my $self = shift;
    return " " x ($self->{indentLevel}*4);
}

sub _linebreak
{
    my $self = shift;
    my %args = (line => undef,
                linebreak => 0,
                @_);

    my @lines;

    while (length($args{line})>$args{linebreak}) {
        my $head = substr($args{line}, 0, $args{linebreak});
        my $tail = substr($args{line}, $args{linebreak});

        if ($tail =~ /^(\S*)\s(.*)$/) {
            push(@lines, $head . "$1");
            $args{line} = $2;
        } else {
            last;
        }
    }
    push(@lines, $args{line});
    return @lines;
}

sub append
{
    my $self = shift;
    my %args = (line => undef,
                linesRef => [""],
                @_);

    if ($args{line}) {
        $args{linesRef} = [$args{line}];
    }

    for my $line (@{$args{linesRef}}) {
        chomp($line);
        ${$self->{linebuffer}}[-1] = ${$self->{linebuffer}}[-1] . $line;
    }

}

sub newLine
{
    my $self = shift;
    push(@{$self->{linebuffer}}, $self->_indentString());
}

sub addLine
{
    my $self = shift;
    my %args = (line => undef,
                linesRef => [""],
                preserveIndent => undef,
                linebreak => 0,
                @_);

    if ($args{line}) {
        $args{linesRef} = [$args{line}];
    }

    my @lines;
    if ($args{linebreak}) {
        $args{linebreak} -= length($self->_indentString());
        for my $line (@{$args{linesRef}}) {
            push(@lines, $self->_linebreak(line => $line,
                                           linebreak => $args{linebreak}));
        }
    } else {
        @lines = @{$args{linesRef}};
    }

    for my $line (@lines) {
        chomp($line);
        unless ($args{preserveIndent}) {
            $line =~ /\s*(.*)/;
            push(@{$self->{linebuffer}}, $self->_indentString() . $1 . "\n");
        } else {
            push(@{$self->{linebuffer}}, "$line\n");
        }
    }
}

sub MakeLink
{
    my $class = shift;
    my %args = (fromDocEnv => undef,
                toDocEnv => undef,
                mark => undef,
                @_);

    return "unresolved linke"
        unless $args{fromDocEnv} && $args{toDocEnv};

    if ($args{toDocEnv} =~ /^http/) {
        if ($args{mark}) {
            return join("#", $args{toDocEnv}, $args{mark});
        }
        return $args{toDocEnv};
    } else {
        $args{toDocEnv} = Link->LookUpDocumentId(documentId => $args{toDocEnv});
    }

    my $currentPath = $args{fromDocEnv}->{outputPath};
    my $destinationPath = $args{toDocEnv}->{outputPath};
    my $prefix = $args{fromDocEnv}->{outputPathPrefix};
    my $outputFile = $args{toDocEnv}->{outputFilename};

    my $relPath = DocUtils->_RelativePath(filename => $outputFile,
                                          fromPath => $currentPath,
                                          toPath => $destinationPath);

    if ($args{mark}) {
        return join("#", $relPath, $args{mark});
    }
    return "$relPath";
}

1;
