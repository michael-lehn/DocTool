package Block;
use strict;
use Function;
use Box;
use Code;
use CodeRef;
use File;
use Latex;
use Image;
use Shell;

BEGIN {
    our @Components = (qw(Box),
                       qw(Code),
                       qw(CodeRef),
                       qw(File),
                       qw(Latex),
                       qw(Image),
                       qw(Shell));

    our %Components;

    for my $component (@Block::Components) {
        my $keyword = $component->Keyword();
        $Block::Components{$keyword} = $component;
    }
}

#
#   Look for lines like  "___ CODE ___" which are usually created by :import:
#


sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    my $chars = "-_=";
    return undef
        unless $args{linebuffer}->line() =~ /^\s*([${chars}])[${chars}]{2,}/;

    my $char = $1;

    return undef
        unless $args{linebuffer}->line()
        =~/^(\s*)[${char}]{3,}\s*([^$char\s].*[^$char\s])\s*[${char}]{3,}\s*$/;

    my $l = length($1);
    my $keyword = $2;
    my $optionString = "";

    if ($keyword =~ s/\s*\((.*?)\)//) {
        $optionString = $1;
    }
    ($keyword, $optionString) = Function->Expand(keyword => $keyword,
                                         optionString => $optionString,
                                         docEnv => $args{linebuffer}->{docEnv});

    my @lines;
    while (! $args{linebuffer}->end()) {
        if ($args{linebuffer}->line() =~ /^\s{$l,$l}$char{6,}\s*$/) {
            $args{linebuffer}->moveLineCursor(offset => 1);
            last;
        }
        if ($args{linebuffer}->line() =~ /^\s{$l,$l}(.*)$/) {
            push(@lines, $1);
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        print "[ERROR] Line ",
              $args{linebuffer}->currentLineNumber(),
              ": Block not terminated correctly\n";
        die;
    }
    shift(@lines);
    return $Block::Components{$keyword}->new(lines => [ @lines ],
                                          docEnv => $args{linebuffer}->{docEnv},
                                          optionString => $optionString);
}

1;
