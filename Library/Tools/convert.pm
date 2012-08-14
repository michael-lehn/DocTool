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

#
#   First convert source code to plain html.
#
sub _SourceToPlainHtml
{
    my $class = shift;
    my %args = (sourceCodeInfoId => undef,
                fileExtension    => "txt",
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
    my $convert = join(" ", "$ENV{VIM} -e -f",
                             $syntaxOnOff, #$numbers,
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

        $line =~ s/<font color="(#[^"]*)">/<span style="color:$1">/g;
        $line =~ s/<\/font>/<\/span>/g;
    }


    while (my $line = shift(@linebuffer)) {
        last if $line =~ /<body/;
    }

    while (my $line = pop(@linebuffer)) {
        last if $line =~ /<\/body/;
    }

#
#   Remove <font face="monospace">
#
    my $blub = shift(@linebuffer);

#
#   Remove </font>
#
    pop(@linebuffer);

    for (my $count=0; $count<=$#linebuffer; ++$count) {
        my $str = sprintf("%5d", $count+1);
        $linebuffer[$count] = "<!-- CodeLine $str -->" . $linebuffer[$count];
    }

    $info->{html} = \@linebuffer;
    $Convert::SourceCodeInfo{$id} = $info;
}

#
#   Auxiliary function that patches the c++ source code that is already
#   converted to html
#
sub _ReplaceInHtml
{
    my %args = (htmlString => undef,
                col        => undef,
                search     => undef,
                replace    => undef,
                @_);

    my $string = $args{htmlString};
    my $col    = 0;
    my $offset = 0;

#
#   Skip first <a ...>...</a><font ...>...</font>
#
    if ($string =~ "^(<a[^>]*>[^<]*</a><font[^>]*>[^<]*</font>)(.*)") {
        $offset += length($1);
        $string = $2;
    }

    $args{search} =~ s/</\&lt;/g;
    $args{search} =~ s/>/\&gt;/g;

    do {
#
#       Skip html tags
#
        while ($string =~ /^(<[^>]*>)(.*)/) {
            $offset += length($1);
            $string = $2;
        }
#
#       Move at most one character forward
#
        if ($col<$args{col}) {
            if ($string =~ /^(&nbsp;)(.*)/) {
                $offset += length($1);
                $string = $2;
            } elsif ($string =~ /^(&lt;)(.*)/) {
                $offset += length($1);
                $string = $2;
            } elsif ($string =~ /^(&gt;)(.*)/) {
                $offset += length($1);
                $string = $2;
            } elsif ($string =~ /^(&quot;)(.*)/) {
                $offset += length($1);
                $string = $2;
            } elsif ($string =~ /^(&amp;)(.*)/) {
                $offset += length($1);
                $string = $2;
            } elsif ($string =~ /^.(.*)/) {
                ++$offset;
                $string = $1;
            } else {
                die "Ooops: col=$col, args{col}=$args{col}, " .
                    "args{htmlString} = $args{htmlString}, " .
                    "string=$string\n\n";
            }
            ++$col;
        }
#
#       Skip html tags
#
        while ($string =~ /^(<[^>]*>)(.*)/) {
            $offset += length($1);
            $string = $2;
        }
    } while ($col<$args{col});

    my $found = substr($args{htmlString}, $offset, length($args{search}));
    if ($found ne $args{search}) {
        printf STDERR "[ERROR] found='$found', search='$args{search}'\n";
        printf STDERR "[ERROR] htmlString = $args{htmlString}\n";
        die;
    }

    substr($args{htmlString}, $offset, length($args{search}), $args{replace});
    return $args{htmlString};
}


sub _MakeCrossRefLink
{
    my %args = (docEnv   => undef,
                dest     => undef,
                destLine => undef,
                keyword  => undef,
                @_);

    my $dest     = $args{dest};
    my $destLine = $args{destLine};

#   If $dest is an array reference return a list of links ...
    if (ref($dest) eq "ARRAY"){
        my $tip = "onmouseover=\"Tip('#TEXT#', WIDTH, 0, " .
                  "TITLE, '#TITLE#', SHADOW, false, FADEIN, 0, " .
                  "FADEOUT, 0, STICKY, 1, CLOSEBTN, true, " .
                  "CLICKCLOSE, true)\" onmouseout=\"UnTip()\"";

        $tip =~ s/#TITLE#/$args{keyword}/g;

        my $css = "class=\"codelink_listitem\"";
        my $text = "<table $css>";
        for (my $i=0; $i<=$#{$dest}; ++$i) {

            my $item = sprintf("%04d", $destLine->[$i]);
            $item =~ /^(0*)/;
            my $replace = "&nbsp;" x length($1);
            $item =~ s/^0*/$replace/;


            unless ($dest->[$i] =~ /^\[external\]\s*(.*)$/) {
                my $docId = "file:$dest->[$i]";
                my $link = Html->MakeLink(fromDocEnv => $args{docEnv},
                                          toDocEnv => $docId);

                $item .= "&nbsp;"x4 . $dest->[$i];
                $text .= "<tr $css><td $css>" .
                         "<a href=\"$link#$destLine->[$i]\" $css>$item</a>" .
                         "</td></tr>";
            } else {
                my $css = "class=\"codelink_listitem_external\"";
                $item .= "&nbsp;"x4 . $1;
                $text .= "<tr $css><td $css>$item</td></tr>";
            }
        }
        $text .= "</table>";
        $text =~ s/"/\\'/g;
        $tip =~ s/#TEXT#/$text/g;

        return "<span $tip $css>$args{keyword}</span>";
    }

#   ... otherwise return a simple link
    my $css = "class=\"codelink\"";
    my $docId = "file:$dest";
    my $link = Html->MakeLink(fromDocEnv => $args{docEnv},
                              toDocEnv => $docId);
    $link = "<a href=\"$link#$destLine\" $css>$args{keyword}</a>";
    return $link;
}

#
#   Then finish html creation by adding linenumbers, cross references, ...
#
sub _FinishHtml
{
    my $class = shift;
    my %args = (sourceCodeInfoId => undef,
                linenumbers      => 1,
                cxxIndex         => undef,
                cxxCrossRef      => undef,
                docEnv           => undef,
                @_);

    my $id = $args{sourceCodeInfoId};
    my $info = $Convert::SourceCodeInfo{$id};

    my @html = ();

    my $startMonospace = "<div class=\"code_content\">" .
                         "<span class=\"code_content\">\n";
    my $endMonospace = "</span></div><!--code_content-->\n";

    if ($args{cxxCrossRef}) {
        my %crossRef = %{$args{cxxCrossRef}};

        foreach my $line (sort {$a <=> $b} keys %crossRef) {
            my $string = $info->{html}->[$line];

            foreach my $col (sort {$b <=> $a} keys %{$crossRef{$line}}) {
                my $dest     = $crossRef{$line}->{$col}->{dest};
                my $destLine = $crossRef{$line}->{$col}->{destLine};
                my $keyword  = $crossRef{$line}->{$col}->{keyword};

                my $link = _MakeCrossRefLink(docEnv   => $args{docEnv},
                                             dest     => $dest,
                                             destLine => $destLine,
                                             keyword  => $keyword);

                # printf STDERR "$line:$col   keyword=$keyword\n";
                $string = _ReplaceInHtml(htmlString => $string,
                                         col        => $col,
                                         search     => $keyword,
                                         replace    => $link);

            }
            $info->{html}->[$line] = $string;
        }
    }

    if ($args{linenumbers}) {
        my @numbers;
        my $number = 1;
        my $maxStrLen = length("$#{$info->{html}}");

        for (my $count=0; $count<=$#{$info->{html}}; ++$count, ++$number) {
            my $str = sprintf("%0${maxStrLen}d", $number);
            $str =~ /^(0*)/;
            my $replace = "&nbsp;" x length($1);
            $str =~ s/^0*/$replace/;

            $str = "<a name=\"$number\"></a>" .
                   "<span class=\"docrefcomment\">" .
                   "&nbsp;"x5 .
                   "</span>" .
                   "<!-- LineNumber " . sprintf("%5d", $number) . " -->" .
                   "<span style=\"color:#af5f00\">$str</span><br>\n";
            push(@numbers, $str);
        }

        if ($args{cxxIndex}) {
            die unless $args{docEnv};
            for my $range (keys %{$args{cxxIndex}}) {
                my $destDocEnv = $args{cxxIndex}->{$range}->{docEnv};
                my $mark  = $args{cxxIndex}->{$range}->{id};
                $mark = CxxIndex->CodeId2HtmlMark(codeId => $mark);

                my $link = Html->MakeLink(fromDocEnv => $args{docEnv},
                                          toDocEnv   => $destDocEnv,
                                          mark       => $mark);
                my $linkBeg = "<a href=\"$link\" class=\"docref\">";
                my $linkEnd = '</a>';

                $range =~ /(\d+):\d*-(\d+):\d*/;
                my $from = $1-1;
                my $to = $2-1;

                my $span = "<span class=\"docref\">";

                my $pattern = '(<span style="color:.*">.*</span>)';
                for (my $line=$from; $line<=$to; ++$line) {
                    $numbers[$line] =~ s/$pattern/${linkBeg}${1}${linkEnd}/;
                }

                $pattern = '<!--\s*LineNumber\s*\d+\s*-->';
                $numbers[$from] = $span . $numbers[$from];
                $numbers[$to] =~ s/(<br>)/<\/span> $1/;

                my $replace = "<doc ";
                $pattern = '&nbsp;' x length($replace);
                $replace =~ s/</&lt;/g;
                $replace =~ s/>/&gt;/g;
                $replace = "<a class=\"docrefcomment\" href=\"$link\">" .
                           $replace .
                           "</a>";
                for (my $line=$from; $line<=$from; ++$line) {
                    $numbers[$line] =~ s/$pattern/$replace/;
                }
            }
        }

        my $css="code_listing";
        if ($args{linenumbers}) {
            $css = " code_with_linenumbers";
        }
        @html = ("<table class=\"$css\"><tr><td class=\"code_linenumbers\">\n",
                 $startMonospace,
                 @numbers,
                 $endMonospace,
                 "</td><td class=\"code_content\">\n",
                 $startMonospace,
                 @{$info->{html}},
                 $endMonospace,
                 "</td></tr></table>\n");
    } else {
        @html = ($startMonospace,
                 @{$info->{html}},
                 $endMonospace);
    }

    return \@html;
}

sub _AddSourceCode
{
    my $class = shift;
    my %args = (codelinesRef  => undef,
                type          => "sourceCode",
                fileExtension => "txt",
                syntaxOn      => 1,
                linenumbers   => 1,
                cxxIndex      => undef,
                cxxCrossRef   => undef,
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
                                         source => [@{$args{codelinesRef}}],
                                         html => []};
        $newId = 1;
    } else {
        $id = $Convert::SourceCode{$key};
    }

    # check if this is a new source code block
    if ($newId) {
        Convert->_SourceToPlainHtml(sourceCodeInfoId => $id,
                                    fileExtension => $args{fileExtension},
                                    linenumbers   => $args{linenumbers});
        print STDERR "[INFO]  ... converted source code file.\n";
    } else {
        print STDERR "[INFO]  ... reusing converted source code file.\n";
    }

    return Convert->_FinishHtml(sourceCodeInfoId => $id,
                                linenumbers      => $args{linenumbers},
                                fileExtension    => $args{fileExtension},
                                cxxIndex         => $args{cxxIndex},
                                cxxCrossRef      => $args{cxxCrossRef},
                                docEnv           => $args{docEnv});
}

sub CodeBlock
{
    my $class = shift;
    my %args = (codelinesRef  => undef,
                fileExtension => "txt",
                linenumbers   => 1,
                cxxIndex      => undef,
                cxxCrossRef   => undef,
                docEnv        => undef,
                @_);

    die "Convert->CodeBlock needs to receive a reference to source code"
        unless defined $args{codelinesRef};

    return @{Convert->_AddSourceCode(%args)};
}

1;
