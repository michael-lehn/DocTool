package Defs;
use strict;
use Import;

sub SET
{
    my ($class, $docEnv, $defValue) = @_;

    my $web = undef;
    if ($defValue =~ /\s*(\S+)\s*=\s*(.*)\s*/) {
        $docEnv->{vars}->{uc($1)} = $2;
    } else {
        die "[ERROR] Defs: Cannot parse assignment \"$defValue\"";
    }
    return 1;
}

sub FUNCTION
{
    my ($class, $docEnv, $defValue) = @_;

    $defValue =~ /^([^( ]*)(\(([^)]*)\))?\s*(.*)/;
    my ($function, $args, $body) = ($1, $3, $4);

    if ($docEnv->{functions}->{$function}) {
        die "[ERROR] redefinition of function \"$function\"\n";
    }
    $docEnv->{functions}->{$function} = {args => $args, body => $body};

    return 1;
}

sub DOCUMENT
{
    my ($class, $docEnv, $defValue) = @_;

    Link->AddDocumentId(documentId => $defValue,
                        docEnv => $docEnv);
    return 1;
}

sub AUTHOR
{
    my ($class, $docEnv, $defValue) = @_;

    my $web = undef;
    if ($defValue =~ s/(.*)\((.*)\)/$1/) {
        $web = $2;
    }

    $docEnv->{vars}->{AUTHOR} = $defValue;
    $docEnv->{vars}->{AUTHOR_WEBSITE} = $web;

    return 1;
}

sub DESCRIPTION
{
    my ($class, $docEnv, $defValue) = @_;

    return Paragraph->new(string => String->new(value => $defValue,
                                                docEnv => $docEnv));
}

sub LINKS
{
    my ($class, $docEnv, @defValue) = @_;

    for my $defValue (@defValue) {
        die "[ERROR] Unable to parse \"$defValue\""
            unless $defValue =~ /^\s*?__(.*)__\s*->\s*(\S.*?)(#(\S.*))?\s*$/;

        unless ((defined $1) && (defined $2)) {
            die "[ERROR] Unable to parse \"$defValue\"";
        }

        Link->ResolveLink(key => $1, destination => $2, mark => $4);
    }
    return Link->DumpUnresolvedLinks(docEnv => $docEnv);
}

sub TOCLEVEL
{
    my ($class, $docEnv, $defValue) = @_;

    $TOC::doc{$docEnv->{sourceFile}}->{maxTocLevel} = $defValue;

    return 1;
}

sub NAVIGATE
{
    my ($class, $docEnv, @defValue) = @_;

    my %navigate = (up   => undef,
                    next => undef,
                    back => undef);

    for my $defValue (@defValue) {
        die "[ERROR] Unable to parse \"$defValue\""
            unless $defValue =~ /^\s*?__(.*)__\s*->\s*(\S.*?)(#(\S.*))?\s*$/;

        unless ((defined $1) && (defined $2)) {
            die "[ERROR] Unable to parse \"$defValue\"";
        }

        my $key         = $1;
        my $destination = $2;
        my $mark        = $4;

        unless (exists $navigate{$key}) {
            die "[ERROR] Unknown navigation keyword \"$key\"";
        }

        if (defined $navigate{$key}) {
            die "[ERROR] Redefining navigation keyword \"$key\"";
        }

        $navigate{$key} = [$destination, $mark];
    }

    $docEnv->{navigate} = \%navigate;
    return 1;
}



sub IMPORT
{
    my ($class, $docEnv, $defValue) = @_;

    $defValue =~ s/\s*\[(.*)\]\s*//;

    return Import->Parse(docEnv => $docEnv,
                         file => $defValue,
                         optionString => $1);
}

sub AUTOLOAD
{
    our $AUTOLOAD;
    warn "[WARNING] Defs: Attempt to call $AUTOLOAD failed.\n";
    return undef;
}

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    return undef unless $args{linebuffer}->line()
                        =~ /^(\s*:(\S+):\s*)(.*)$/;

    my $lineNumber = $args{linebuffer}->currentLineNumber();
    $args{linebuffer}->moveLineCursor(offset => 1);

    my $l = length($1);
    my $defType = uc($2);
    my @defValue = ($3);

    while (! $args{linebuffer}->end()) {
        last unless $args{linebuffer}->line() =~ /^\s{$l,$l}(\S.*)$/;

        push(@defValue, $1);
        $args{linebuffer}->moveLineCursor(offset => 1);
    }

    my $res = $class->$defType($args{linebuffer}->{docEnv}, @defValue);
    unless ($res) {
        die "[ERROR] In line $lineNumber, define statement \"$defType\".\n";
        # just skip the statement
        return 1;
    }

    return $res;
}

1;
