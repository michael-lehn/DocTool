package DocEnv;
use strict;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {sourceFile => undef,
                 sourceFilename => undef,
                 sourceBasename => undef,
                 sourcePath => undef,
                 outputExtension => "html",
                 outputFilename => undef,
                 outputPathPrefix => $ENV{HTML_DIR},
                 outputPath => undef,
                 outputFile => undef,
                 functions => {},
                 navigate => undef,
                 keepExtension => 0,
                 vars => {TITLE => undef,
                          SOURCE_FILENAME => undef,
                          SOURCE_PATH => undef,
                          REL_HTML_DIR => undef,
                          YEAR => $ENV{YEAR},
                          AUTHOR => $ENV{AUTHOR},
                          AUTHOR_WEBSITE => $ENV{AUTHOR_WEBSITE},
                          },
                 @_};
    bless ($self, $class);



    if ($self->{sourceFile}) {
        my $sourcePath = DocUtils->Path(fullpath => $self->{sourceFile});
        my $sourceFilename = DocUtils->Filename(fullpath => $self->{sourceFile});
        my $sourceBasename = DocUtils->Basename(fullpath => $sourceFilename);
        my $sourceExtension = DocUtils->Extension(fullpath => $sourceFilename);

        if ($self->{keepExtension}) {
            $self->{outputExtension} = join(".", $sourceExtension,
                                                 $self->{outputExtension});
        }

        $self->{sourceFilename} = $sourceFilename;
        $self->{sourceBasename} = $sourceBasename;
        $self->{sourcePath} = $sourcePath;

        $self->{outputFilename} = DocUtils->CreateFullpath(
                                    filename => $sourceFilename,
                                    newExtension => $self->{outputExtension});
        $self->{outputPath} = DocUtils->CreateFullpath(
                                    prefix => $self->{outputPathPrefix},
                                    path => $sourcePath);
        $self->{outputFile} = DocUtils->CreateFullpath(
                                    prefix => $self->{outputPathPrefix},
                                    path => $sourcePath,
                                    filename => $sourceFilename,
                                    newExtension => $self->{outputExtension});

        ${$self->{vars}}{REL_HTML_DIR} = DocUtils->RelativePath(
                                    currentPath => $sourcePath,
                                    removeDestinationPrefix =>
                                                $self->{outputPathPrefix},
                                    destinationPath => $ENV{HTML_DIR});
    } else {
         die "[ERROR] no sourcefile given";
    }
    return $self;
}

sub setVariable
{
    my $self = shift;
    my %args = (variable => undef,
                value => undef,
                @_);
    ${$self->{vars}}{$args{variable}} = $args{value};
}

sub updateVars
{
    my $self = shift;

    ${$self->{vars}}{SOURCE_FILENAME} = $self->{sourceFilename};
    ${$self->{vars}}{SOURCE_PATH} = $self->{sourcePath};
}

sub filter
{
    my $self = shift;
    my %args = (file => undef,
                @_);

    $self->updateVars();

    my @linebuffer = DocUtils->LoadLinebuffer(file => $args{file});
    return DocUtils->ExpandVariables(linesRef => \@linebuffer,
                                     varsRef => $self->{vars});
}

1;
