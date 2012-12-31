package Import;
use Options;
use strict;

our $Comment = "\/\/[*-/]";

sub MakeCodeBlock
{
    my $class = shift;
    my %args = (code => undef,
                file => undef,
                create => 0,
                @_);

    my @lines = @{$args{code}};
    @{$args{code}} = ();

    if (scalar(@lines)>0) {
        my $code = "CODE";
        if ($args{file}) {
            $code = $code . " (file=$args{file}, create=$args{create})";
        }
        unshift(@lines, "___ $code ___");

        while ($lines[$#lines] =~ /^\s*$/) {
            pop(@lines);
        }

        push(@lines,    "____________");
    }
    return @lines;
}

sub ExpandBriefComments
{
    my $class = shift;
    my %args = (input => undef,
                @_);

    my @input = @{$args{input}};
    my @output;
    my @codeLines;

    for (my $i=0; $i<=$#input; ++$i) {
        my $line = $input[$i];

        unless ($line =~ /\S/) {
            next;
        }

        unless ($line =~ /^\s*$Import::Comment.*$/) {
            next;
        }

        while ($i<=$#input) {
            $line = $input[$i];

            if ($line =~ /^\s*$Import::Comment(.*)$/) {
                push(@output, $1);
                ++$i;
                next;
            }
            last;
        }

        while ($i<=$#input) {
            $line = $input[$i];
            if (($line =~ /^\s*$/) || ($line =~ /^\s*$Import::Comment-.*$/)) {
                push(@output, Import->MakeCodeBlock(code => \@codeLines));
                last;
            }
            if ($line =~ /^\s*$Import::Comment.*$/) {
                push(@output, Import->MakeCodeBlock(code => \@codeLines));
                --$i;
                last;
            }
            push(@codeLines, $line);
            ++$i;
        }
    }
    push(@output, Import->MakeCodeBlock(code => \@codeLines));
    return @output;
}


sub ExpandComments
{
    my $class = shift;
    my %args = (input => undef,
                @_);

    my @input = @{$args{input}};
    my @output;
    my @codeLines;

    for (my $i=0; $i<=$#input; ++$i) {
        my $line = $input[$i];

        if ($line =~ s/^\s*$Import::Comment(.*)$//) {
            push(@output, Import->MakeCodeBlock(code => \@codeLines));
            push(@output, $1);
            next;
        }

        while ($i<=$#input) {
            unless ($line =~ s/^\s*$Import::Comment(.*)$//) {
                push(@codeLines, $line);
                $line = $input[++$i];
            } else {
                --$i;
                last;
            }
        }
    }
    push(@output, Import->MakeCodeBlock(code => \@codeLines));
    return @output;
}

sub RemoveComments
{
    my $class = shift;
    my %args = (input => undef,
                file => undef,
                create => 0,
                @_);

    my @input = @{$args{input}};
    my @codeLines;

    for (my $i=0; $i<=$#input; ++$i) {
        if ($input[$i] =~ s/^\s*$Import::Comment(.*)$//) {
            next;
        }
        push(@codeLines, $input[$i]);
    }
    return Import->MakeCodeBlock(code => \@codeLines,
                                 file => $args{file},
                                 create => $args{create});
}

sub Parse
{
    my $class = shift;
    my %args = (docEnv => undef,
                file => undef,
                optionString => undef,
                create => 0,
                @_);

    die unless $args{docEnv};
    die unless $args{file};

    my %option = Options->Split(string => $args{optionString});

    my @input = DocUtils->LoadLinebuffer(file => $args{file},
                                         removeNewlines => 1,
                                         removeTrailingSpaces => undef);

    if ($option{downloadable}) {
        my $to = join("/", $ENV{DOWNLOAD_DIR},
                           DocUtils->Path(fullpath => $args{file}));
        DocUtils->Copy(file => $args{file}, to => $to);
    }

    if (($option{file}) && ($option{file} ne $args{file})) {
        $args{file} = $option{file};
        $args{create} = 1;
    }

    my @output;

    if ($option{brief}) {
        @output = Import->ExpandBriefComments(input => \@input);
    } else {
        if ($option{stripped}) {
            @output = Import->RemoveComments(input => \@input,
                                             file => $args{file},
                                             create => $args{create});
        } else {
            @output = Import->MakeCodeBlock(code => \@input,
                                            file => $args{file},
                                            create => $args{create});
        }
    }

    my $linebuffer = Linebuffer->new(buffer => \@output,
                                     docEnv => $args{docEnv});

    return Parse->new(linebuffer => $linebuffer);
}

1;
