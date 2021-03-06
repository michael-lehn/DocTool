package Latex;
use strict;
use Convert;
use DocTool;

sub SingleQuotes
{
    return "\$";
}

sub DoubleQuotes
{
    return undef;
}

sub LeftQuote
{
    return undef;
}

sub RightQuote
{
    return undef;
}

sub Keyword
{
    return "LATEX";
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {string => undef,
                 docEnv => undef,
                 lines => undef,
                 optionString => undef,

                 css_class => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{string} || $self->{lines};

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    if ($self->{string}->{value}) {
        if ($DocTool::createLatexPics) {
            my $depth = 0;
            my $latexFormula = Convert->LatexFormula(
                                      codeline => $self->{string}->{value},
                                      formulaDepthRef => \$depth);
            my $imagePath = DocUtils->Path(fullpath => $latexFormula);
            my $imageFile = DocUtils->Filename(fullpath => $latexFormula);

            my $sourcePath = $args{html}->{docEnv}->{sourcePath};
            my $relPath = DocUtils->RelativePath(currentPath => $sourcePath,
                                      removeDestinationPrefix => $ENV{HTML_DIR},
                                      destinationPath => $imagePath);

            my $html = "<img class=\"formula\"" .
                            " style=\"padding:0px 4px;" .
                            " vertical-align:baseline;" .
                            " position:relative;" .
                            " bottom: ${depth}px;\"" .
                            " src=\"$relPath/$imageFile\"" .
                            " alt=\"some latex code\">";
            $args{html}->append(line => $html);
        } else {
            $args{html}->append(line => "\\(" .
                                $self->{string}->{value} . "\\)");
        }
    }

    if ($self->{lines}) {
        if ($DocTool::createLatexPics) {
            my @code;
            for my $line (@{$self->{lines}}) {
                push(@code, "$line\n")
            }
            my $latexBlock = Convert->LatexBlock(codelinesRef => \@code);
            my $imagePath = DocUtils->Path(fullpath => $latexBlock);
            my $imageFile = DocUtils->Filename(fullpath => $latexBlock);

            my $sourcePath = $args{html}->{docEnv}->{sourcePath};
            my $relPath = DocUtils->RelativePath(currentPath => $sourcePath,
                                     removeDestinationPrefix => $ENV{HTML_DIR},
                                     destinationPath => $imagePath);

            my $html = "<div class=\"centered latex_block\">"
                 . "<img src=\"$relPath/$imageFile\" alt=\"some latex code\">"
                 . "</div>";
            $args{html}->append(line => $html);
        } else {
            unshift(@{$self->{lines}}, "\\[");
            push(@{$self->{lines}}, "\\]");
            $args{html}->append(linesRef => $self->{lines});
        }
    }
}

sub plain
{
    my $self = shift;
    my %args = (@_);

#
#   TODO: If $DocTool::createLatexPic is set this is crap.  Further, it
#         this method ignores $self->{lines}.
#
    return $self->{string}->{value};
}

1;
