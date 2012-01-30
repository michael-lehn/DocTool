package BlockBox;
use strict;
use Function;
use Box;
use Code;
use File;
use Latex;
use Shell;

BEGIN {
    our @Components = (qw(Box),
                       qw(Code),
                       qw(Latex),
                       qw(Shell));

    our %Components;

    for my $component (@Block::Components) {
        my $keyword = $component->Keyword();
        $Block::Components{$keyword} = $component;
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
    shift(@lines);
    return $Block::Components{$keyword}->new(lines => [ @lines ],
                                          docEnv => $args{linebuffer}->{docEnv},
                                          optionString => $optionString);
}

1;
