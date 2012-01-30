package Convert;
use strict;
use BerkeleyDB;
use MLDBM qw(BerkeleyDB::Btree);
use Data::Dumper;

BEGIN {
    our $FormulaBasename = "LatexFormula";
    our $SourceCodeBasename = "SourceCode";

    die "[ERROR] Convert: \"DB_DIR\" not specified in configuration."
        unless defined $ENV{DB_DIR};

    DocUtils->Mkdir(path => $ENV{DB_DIR});

    #-- SourceCode
    #
    #   KEY:    source code
    #   VALUE:  source code id
    #
    tie our %SourceCode, "BerkeleyDB::Hash",
        -Filename => "$ENV{DB_DIR}/SourceCode.db",
        -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/SourceCode.db\"";

    #-- SourceCodeInfo
    #
    #   KEY:    source code id
    #   VALUE:  info hash
    #
    tie our %SourceCodeInfo, "MLDBM",
        -Filename => "$ENV{DB_DIR}/SourceCodeInfo.db",
        -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/SourceCodeInfo.db\"";
}

################################################################################
#
#   Latex
#

sub _GetNewSourceCodeId
{
    return 1 + scalar keys %Convert::SourceCode;
}

sub _LatexToPng
{
    my $class = shift;
    my %args = (latexFile => undef,
                pngFile => undef,
                @_);

    my $sourcePath = DocUtils->Path(fullpath => $args{latexFile});
    my $outputPath = DocUtils->Path(fullpath => $args{pngFile});
    my $outputFile = DocUtils->Filename(fullpath => $args{pngFile});

    my $filebase = DocUtils->Basename(fullpath => $args{latexFile});

    $sourcePath = "." unless $sourcePath;

    my $cd = "cd $sourcePath";
    my $latex = "latex --interaction=nonstopmode ${filebase}.tex > /dev/null";
    my $dvips = "dvips -E -o ${filebase}.ps ${filebase}.dvi > /dev/null 2>&1";
    my $convert = "convert -density 120 -transparent \"#FFFFFF\" " .
                  "${filebase}.ps ${filebase}.png";

    #   my $convert = "convert -density 150 -transparent \"#FFFFFF\" " .
    #                 "-flatten -trim +repage " .
    #                 "${filebase}.ps ${filebase}.png";


    system("$cd; $latex");
    system("$cd; $dvips");
    system("$cd; $convert");

    DocUtils->Install(filename => "${filebase}.png",
                      from => $sourcePath,
                      to => $outputPath,
                      newFilename => $outputFile);
}

sub _AddLatexFormula
{
    my $class = shift;
    my %args = (codelinesRef => undef,
                formulaDepthRef => undef,
                @_);

    # compress latex code a bit
    my $key = join("", @{$args{codelinesRef}});
    $key =~ s/ //g;
    $key =~ s/\n//g;

    my $id;
    my $newId = undef;
    unless (defined $Convert::SourceCode{$key}) {
        $id = Convert->_GetNewSourceCodeId();
        $Convert::SourceCode{$key} = $id;
        $Convert::SourceCodeInfo{$id} = {type => "tex",
                                         depth => 0};
        $newId = 1;
    } else {
        $id = $Convert::SourceCode{$key};
    }

    my $basename = $Convert::FormulaBasename;
    my $pngFile = DocUtils->CreateFullpath(basename => $basename . $id,
                                           extension => "png",
                                           prefix => $ENV{IMAGE_DIR});
    # check if this is a new formula
    if (defined $newId) {
        my $latexFile = DocUtils->CreateFullpath(basename => $basename . $id,
                                                 extension => "tex",
                                                 prefix => $ENV{TMP_DIR});
        DocUtils->SaveLinebuffer(file=> $latexFile,
                                 linesRef => $args{codelinesRef});
        Convert->_LatexToPng(latexFile => $latexFile, pngFile => $pngFile);
        print STDERR "[INFO]  ... new latex formula: $pngFile\n";
    } else {
        print STDERR "[INFO]  ... reusing latex formula: $pngFile\n";        
    }
    if (defined $args{formulaDepthRef}) {
        if (defined $newId) {
            my $logFile = DocUtils->CreateFullpath(basename => $basename . $id,
                                                   extension => "log",
                                                   prefix => $ENV{TMP_DIR});
            my $logFh = FileHandle->new("< $logFile");
            my @depths = grep /\/\/depth=(.*)pt\/\//, <$logFh>;
            $depths[0] =~ s/\/\/depth=(.*)pt\/\/.*/$1/;

            # modify 'depth' info
            my $info = $Convert::SourceCodeInfo{$id};
            $info->{depth} = int(-7-$depths[0]*1.8);
            $Convert::SourceCodeInfo{$id} = $info;

        }
        ${$args{formulaDepthRef}} = $Convert::SourceCodeInfo{$id}->{depth};
    }
    return $pngFile;
}

sub LatexFormula
{
    my $class = shift;
    my %args = (codeline => undef,
                formulaDepthRef => undef,
                @_);

    die "Convert->LatexBlock needs to receive a reference to latex code"
        unless defined $args{codeline};

    my @codelines;
    push(@codelines, DocUtils->LoadLinebuffer(file => $ENV{LATEX_FORMULA}));
    s/##LATEXFORMULA##/$args{codeline}/ for (@codelines);

    return Convert->_AddLatexFormula(codelinesRef => \@codelines,
                                     formulaDepthRef => $args{formulaDepthRef});
}

sub LatexBlock
{
    my $class = shift;
    my %args = (codelinesRef => undef,
                @_);

    die "Convert->LatexBlock needs to receive a reference to latex code"
        unless defined $args{codelinesRef};

    my @codelines;
    push(@codelines, DocUtils->LoadLinebuffer(file => $ENV{LATEX_HEADER}));
    push(@codelines, @{$args{codelinesRef}});
    push(@codelines, DocUtils->LoadLinebuffer(file => $ENV{LATEX_FOOTER}));

    return Convert->_AddLatexFormula(codelinesRef => \@codelines);
}

################################################################################
#
#   Source Code
#

sub _SourceToHtml
{
    my $class = shift;
    my %args = (sourceCodeInfoId => undef,
                fileExtension => "txt",
                linenumbers   => 1,
                @_);

    my $id = $args{sourceCodeInfoId};
    my $info = $Convert::SourceCodeInfo{$id};

    my $tmpFile = DocUtils->CreateFullpath(path => $ENV{TMP_DIR},
                                           basename => "source",
                                           extension => $args{fileExtension});

    DocUtils->SaveLinebuffer(file => $tmpFile,
                             linesRef => $info->{source},
                             appendNewLine => 1);

    my $syntaxOnOff = "-c \"syntax on\" ";
    my $numbers = ($args{linenumbers}) ? "-c \"set number\"" : "";
    my $convert = join(" ", "$ENV{VIM} -e -f",
                             $syntaxOnOff, $numbers,
                             "-c \"let g:html_use_css=0\"",
                             "-c \"runtime! syntax/2html.vim\"",
                             "-c \"wq\" -c \"q\" $tmpFile > /dev/null");
    my $clean = "rm ${tmpFile}.html";
    system "$convert";

    my @linebuffer = DocUtils->LoadLinebuffer(file => "${tmpFile}.html"); 

    foreach my $line (@linebuffer) {
        # yellow of 'using'
        $line =~ s/#ffff00/#af5f00/g;
        # green of 'namespace', 'double', 'int'
        $line =~ s/#00ff00/#008000/g;
        # red of string, constants, ..
        $line =~ s/#ff6060/#c00000/g;
        $line =~ s/#ff40ff/#c000c0/g;
    }


    while (my $line = shift(@linebuffer)) {
        last if $line =~ /<body/;
    }

    while (my $line = pop(@linebuffer)) {
        last if $line =~ /<\/body/;
    }

#    system "$clean";


    @{$info->{html}} = ();
    push(@{$info->{html}}, "<div class=\"code_content\">"
                         . "<font face=\"monospace\">\n");
    push(@{$info->{html}}, @linebuffer);
    push(@{$info->{html}}, "</font></div>\n");
    push(@{$info->{html}}, "</div>\n");
    $Convert::SourceCodeInfo{$id} = $info;
}

sub _AddSourceCode
{
    my $class = shift;
    my %args = (codelinesRef => undef,
                type => "sourceCode",
                fileExtension => "txt",
                syntaxOn => 1,
                linenumbers => 1,
                @_);

    my $key = join("", @{$args{codelinesRef}});

    my $id;
    my $newId = 0;
    unless (defined $Convert::SourceCode{$key}) {
        $id = Convert->_GetNewSourceCodeId();
        $Convert::SourceCode{$key} = $id;
        $Convert::SourceCodeInfo{$id} = {type => $args{type},
                                         fileExtension => $args{fileExtension},
                                         syntaxOn =>  $args{syntaxOn},
                                         linenumbers => $args{linenumbers},
                                         source => [@{$args{codelinesRef}}],
                                         html => []};
        $newId = 1;
    } else {
        $id = $Convert::SourceCode{$key};
    }

    # check if this is a new source code block
    if ($newId) {
        Convert->_SourceToHtml(sourceCodeInfoId => $id,
                               fileExtension => $args{fileExtension},
                               linenumbers   => $args{linenumbers});
        print STDERR "[INFO]  ... converted source code file.\n";
    } else {
        print STDERR "[INFO]  ... reusing converted source code file.\n";
    }

    return @{$Convert::SourceCodeInfo{$id}->{html}};
}

sub CodeBlock
{
    my $class = shift;
    my %args = (codelinesRef => undef,
                fileExtension => "txt",
                linenumbers   => 1,
                @_);

    die "Convert->CodeBlock needs to receive a reference to source code"
        unless defined $args{codelinesRef};

    return Convert->_AddSourceCode(%args);
}

1;
