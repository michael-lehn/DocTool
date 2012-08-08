package BlockBox;
use strict;
use Function;
use Box;
use Code;
use CodeRef;
use File;
use Latex;
use Shell;

BEGIN {
    our @Components = (qw(Box),
                       qw(Code),
                       qw(CodeRef),
                       qw(Latex),
                       qw(Shell));

    our %Components;

    for my $component (@BlockBox::Components) {
        my $keyword = $component->Keyword();
        $BlockBox::Components{$keyword} = $component;
    }
}

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    return undef
        unless $args{linebuffer}->line()
               =~ /^(\s*)(\*-{2,}(\[(.*)\])-{2,}\*)\s*$/;

    $args{linebuffer}->moveLineCursor(offset => 1);

    my $indent  = $1;
    # inner width
    my $width   = length($2)-2;
    my $keyword = $4;

    my $l = length($indent);
    my $optionString = "";

    if ($keyword =~ s/\s*\((.*?)\)//) {
        $optionString = $1;
    }
    ($keyword, $optionString) = Function->Expand(keyword => $keyword,
                                         optionString => $optionString,
                                         docEnv => $args{linebuffer}->{docEnv});

    my @lines;
    while (! $args{linebuffer}->end()) {
        if ($args{linebuffer}->line() =~ /^\s{$l,$l}\*-{$width,$width}\*\s*$/) {
            $args{linebuffer}->moveLineCursor(offset => 1);
            last;
        }
        if ($args{linebuffer}->line() =~ /^\s{$l,$l}\|(.{$width,$width})\|\s*$/) {
            push(@lines, $1);
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        print "[ERROR] Line ",
              $args{linebuffer}->currentLineNumber(),
              ": BlockBox not terminated correctly\n";
        die;
    }

#
#   Remove first or last line if they are empty
#
    if ($lines[0] =~ /^\s*$/) {
        shift(@lines);
    }
    if ($lines[-1] =~ /^\s*$/) {
        pop(@lines);
    }

    unless ($BlockBox::Components{$keyword}) {
        die "Undefined component '$keyword'\n\n";
    }


#
#   Look for additional option
#
    my $moreOptions = undef;
    while (! $args{linebuffer}->end()) {
        if ($args{linebuffer}->line() =~ /^\s{$l,}\[(.+)\]\s*$/) {
            $moreOptions .= $1;
            $args{linebuffer}->moveLineCursor(offset => 1);
        } else {
            last;
        }
    }
    if ($moreOptions) {
        $moreOptions =~ s/\s*$//;
        if ($optionString) {
            $optionString = join(";", ($optionString, $moreOptions));
        } else {
            $optionString = $moreOptions;
        }
    }

#
#   Look for additional description.  These have an additional ident of at
#   least 3 spaces.
#
    my $L = $l + 3;
    my @description = ();

    while (! $args{linebuffer}->end()) {
        if ($args{linebuffer}->line() =~ /^(\s*)\S/) {
            last if (length($1)<$L);
        }
        push(@description, $args{linebuffer}->line());
        $args{linebuffer}->moveLineCursor(offset => 1);
    }


    my $linebuffer = Linebuffer->new(buffer => \@description,
                                     docEnv => $args{linebuffer}->{docEnv});
    my $description = Parse->new(linebuffer => $linebuffer);
    while (! $linebuffer->end()) {
        print "> ", $linebuffer->line(), "\n";
        $linebuffer->moveLineCursor(offset => 1);
    }

    return $BlockBox::Components{$keyword}->new(lines => [ @lines ],
                                          docEnv => $args{linebuffer}->{docEnv},
                                          optionString => $optionString,
                                          description => $description);
}

1;
