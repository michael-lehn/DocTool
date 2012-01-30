package File;
use strict;
use String;
use Options;
use DocUtils;

sub Keyword
{
    return "FILE";
}

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {lines => undef,
                 docEnv => undef,
                 optionString => "",
                 options => undef,
                 html => undef,
                 @_};
    bless ($self, $class);

    # handle options
    $self->{options} = {file => "",
                        create => 1,
                        downloadable => 1,
                        Options->Split(string => $self->{optionString})};

    if (($self->{options}->{file}) && ($self->{options}->{downloadable})) {
        my $filename = join("/", $ENV{DOWNLOAD_DIR}, $self->{options}->{file});
        DocUtils->SaveLinebuffer(file => $filename,
                                 linesRef => $self->{lines},
                                 appendNewLine => 1);
    }
    if (($self->{options}->{file}) && ($self->{options}->{create})) {
        my $filename = join("/", $ENV{CODE_DIR}, $self->{options}->{file});
        DocUtils->SaveLinebuffer(file => $filename,
                                 linesRef => $self->{lines},
                                 appendNewLine => 1);
    }

    die unless $self->{docEnv};

    return $self;
}

sub html
{
}

1;