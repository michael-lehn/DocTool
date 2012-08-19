package Image;
use strict;
use Convert;
use DocTool;

sub SingleQuotes
{
    return undef;
}

sub DoubleQuotes
{
    return undef;
}

sub Keyword
{
    return "IMAGE";
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

    if ($self->{lines}) {
        $args{html}->append(line => "<div class=\"centered\">");
        for my $line (@{$self->{lines}}) {
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            next unless $line =~ /\S/;
#
#           TODO: Check if "from/filename" exists and otherwise die!
#

#           I think its more transparent to specify the image file relative
#           to DOCSRC_DIR ...
#
#            DocUtils->Install(from => $args{html}->{docEnv}->{sourcePath},
#                              filename => $line,
#                              to => $args{html}->{docEnv}->{outputPath});
            DocUtils->Install(from => $ENV{DOCSRC_DIR},
                              filename => $line,
                              to => $ENV{HTML_DIR});
            $line = DocUtils->_RelativePath(filename => $line,
                                    fromPath => $args{html}->{docEnv}->{outputPath},
                                    toPath =>   $ENV{HTML_DIR});
            $args{html}->append(line => "<img src=\"$line\">\n");
        }
        $args{html}->append(line => "</div>");
    }
}

1;
