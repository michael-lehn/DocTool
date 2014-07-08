package Shell;
use strict;
use String;

BEGIN {
    our $MagicNumber = "#6#6#6#!# ";
}

sub Keyword
{
    return "SHELL";
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {lines => undef,
                 optionString => undef,
                 docEnv => undef,

                 content => undef,

                 @_};
    bless ($self, $class);

    die unless $self->{docEnv};

    # handle options
    $self->{options} = {hide => undef,
                        path => ".",
                        height => undef,
                        Options->Split(string => $self->{optionString})};


    # remove empty lines
    # concat lines that end on "+++"
    my @lines;
    for (my $i=0; $i<=$#{$self->{lines}}; ++$i) {
        my $line = $self->{lines}->[$i];
        chomp($line);

        # read ahead if line ends on "+++"
        while ($line =~ /^(.*?)\s*\+\+\+\s*$/) {
            $line = $1;
            $self->{lines}->[++$i] =~ s/^\s*/ /;
            $line = $line . $self->{lines}->[$i];
            chomp($line);
        }

        if ($line =~ /\S/) {
            push(@lines, $line);
        }
    }
    $self->{lines} = \@lines;
    $self->execute();

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    if ($self->{options}->{hide}) {
        return;
    }

    #$self->convert();
    for my $line (@{$self->{html}}) {
        $args{html}->addLine(line => $line, preserveIndent => 1);
    }
}

sub execute
{
    my $self = shift;

    my $shellScript = DocUtils->CreateFullpath(basename => "shell",
                                               extension => "sh",
                                               prefix => $ENV{TMP_DIR});

    DocUtils->SaveLinebuffer(file => $shellScript,
                             linesRef => $self->{lines},
                             appendNewLine => 1);

    my $shellOutput = DocUtils->CreateFullpath(basename => "shell_output",
                                               extension => "sh",
                                               prefix => $ENV{TMP_DIR});
    my $cmd = "mkdir -p $ENV{SHELL_HOME_DIR};" .
              "cd $ENV{SHELL_HOME_DIR};" .
              "cd $self->{options}->{path};".
              "export PS4='$Shell::MagicNumber';" .
              "bash -vx $shellScript > $shellOutput 2>&1";
    my $exitCode = system($cmd);

    my @shellOutput = DocUtils->LoadLinebuffer(file => $shellOutput,
                                               removeNewlines => 1);

    my @html;
    my $style = "";

    if ($self->{options}->{height}) {
        $style = "style=\"height:$self->{options}->{height}em;\"";
    }

    if ($exitCode==0) {
        push(@html, "<div class=\"shell\" $style><pre>\n");
    } else {
        push(@html, "<div class=\"shell shell_error\" $style><pre>\n");
    }

    my $inCmd = undef;
    for (my ($i, $I) = (0, 0); $i<=$#shellOutput; ++$i) {
        if ($shellOutput[$i] && ${$self->{lines}}[$I] &&
            ($shellOutput[$i] eq ${$self->{lines}}[$I])) {
            unless ($inCmd) {
                my $cmd = $shellOutput[$i];
                $cmd =~ s/^\s*//;

                push(@html, "<span class=\"cmd\">" .
                            "\$shell> " . $cmd .
                            "</span>\n");
            } else {
                push(@html, "<span class=\"cmd\">" .
                            ">       " . $shellOutput[$i] .
                            "</span>\n");
            }
            unless ($shellOutput[$i] =~ /^\s*#/) {
                $inCmd = 1;
            }
            ++$I;
        } else {
            $inCmd = undef;
            if ($shellOutput[$i] =~ /^$Shell::MagicNumber/) {
                next;
            }
            if ($shellOutput[$i] =~ s/$Shell::MagicNumber.*$//) {
                $shellOutput[$i+1] = $shellOutput[$i] . $shellOutput[$i+1];
                next;
            }
            if ($shellOutput[$i]) {
                push(@html, $shellOutput[$i]);
            }
        }
    }
    push(@html, "</pre></div>\n");
    $self->{html} = \@html;
}

sub convert
{
    my $self = shift;

    my $syntaxOnOff = "-c \"syntax off\"";

    # my $numbers = "-c \"set number\"";
    my $numbers = "";

    my $shellLog = DocUtils->CreateFullpath(basename => "shell_log",
                                            extension => "sh",
                                            prefix => $ENV{TMP_DIR});

    my @log = DocUtils->LoadLinebuffer(file => $shellLog);

    my @outBuffer;
    push(@outBuffer, "<div class=\"shell\"><font face=\"monospace\"><pre>\n");

    for (my $i=0; $i<=$#log; ++$i) {
        chomp($log[$i]);
#        if (($i<$#log) && ($log[$i+1] =~ /^\+\s/)) {
#            push(@outBuffer, "<span class=\"cmd\">\$> " .
#                             $log[$i] .
#                             "</span>\n");
#            ++$i;
#            next;
#        }
        push(@outBuffer, $log[$i] . "\n");
    }
    push(@outBuffer, "</pre></font></div>\n");
    @{$self->{html}} = @outBuffer;
}

1;
