package SourceFiles;
use strict;
use Convert;
use Html;
use Link;
use DirHandle;
use List::MoreUtils qw/uniq/;

BEGIN {
    our @SourceFiles = (qw(cc), qw(tcc), qw(cpp), qw(cxx), qw(c++), qw(f));
    our @HeaderFiles = (qw(h), qw(hpp), qw(hxx), qw(h++));
    our @AllFiles = (@SourceFiles, @HeaderFiles);
}

sub ProcessFile
{
    my $class = shift;
    my %args = (file => undef,
                prefix => $ENV{DOCSRC_DIR},
                outputPrefix => $ENV{HTML_DIR},
                @_);

    my $sourceFile = $args{file};

    print STDERR "[INFO] Processing source file $sourceFile ...\n";
    my $path = DocUtils->Path(fullpath => $sourceFile);
    my $filename = DocUtils->Filename(fullpath => $sourceFile);
    my $ext = DocUtils->Extension(fullpath => $sourceFile);

    my $docEnv = DocEnv->new(sourceFile => $args{file},
                             keepExtension => 1);
    my $docId = "file:$args{file}";
    print STDERR "[INFO]  ... DocId will be \"$docId\"\n";
    print STDERR "[INFO]  ... and output saved as ", $docEnv->{outputFile}, "\n";
    Link->AddDocumentId(docEnv => $docEnv, documentId => $docId);

    $docEnv->setVariable(variable => qw(TITLE),
                         value => "$filename ($sourceFile)");

    $docEnv->{vars}->{HOME} = Html->MakeLink(fromDocEnv => $docEnv,
                                             toDocEnv => "doc:index");

    my $currentPath = $docEnv->{sourcePath};
    my $filetreeLink = Html->MakeLink(fromDocEnv => $docEnv,
                                      toDocEnv => "dir:$currentPath/");
    $docEnv->{vars}->{FILETREE} = $filetreeLink;

    my @lines;
    $docEnv->{sourceFilename} = undef;
    push(@lines, $docEnv->filter(file => $ENV{SOURCEFILE_HEADER}));

    my @source = DocUtils->LoadLinebuffer(prefix => $args{prefix},
                                          file => $sourceFile,
                                          removeNewlines => 1);
    push(@lines, Convert->CodeBlock(codelinesRef => \@source,
                                    fileExtension => $ext));
    push(@lines, $docEnv->filter(file => $ENV{SOURCEFILE_FOOTER}));
    DocUtils->SaveLinebuffer(file => $docEnv->{outputFile},
                             linesRef => \@lines);

}

sub ProcessFiles
{
    my $class = shift;
    my %args = (prefix => $ENV{DOCSRC_DIR},
                outputPrefix => $ENV{HTML_DIR},
                @_);

    my @sourceFiles = $class->ScanDirectory();
    for my $sourceFile (@sourceFiles) {
        $class->ProcessFile(%args, file => $sourceFile);
    }
    print STDERR "[INFO] Total of " .
                 scalar(@sourceFiles) .
                 " files processed\n";
}

sub ScanDirectory
{
    my $class = shift;
    my %args = (prefix => $ENV{DOCSRC_DIR},
                path => undef,
                extraExtensions => undef,
                onlyFiles => 0,
                @_);

    my @found = ();

    my $fullpath = DocUtils->CreateFullpath(prefix => $args{prefix},
                                            path => $args{path});
    my $dh = DirHandle->new($fullpath) || die ("cannot open dir: $args{path}");


    my @subdirs = ();
    while (my $item = $dh->read()) {
        next if ($item eq ".") || ($item eq "..");

        my $itemPath = DocUtils->CreateFullpath(prefix => $args{path},
                                                path => $item);
        my $itemFullpath = DocUtils->CreateFullpath(prefix => $fullpath,
                                                    path => $item);

        unless ($args{onlyFiles}) {
            if (-d $itemFullpath) {
                push(@found, $class->ScanDirectory(%args,
                                                   path => $itemPath,
                                                   prefix => $args{prefix}));
            }
        }

        if (-f $itemFullpath) {
            my $extension = DocUtils->Extension(fullpath => $item);


            if (grep {$_ eq $extension} @SourceFiles::AllFiles) {
                push(@found, $itemPath);
                next;
            }

            if (defined $args{extraExtensions}) {
                if (grep {$_ eq $extension} @{$args{extraExtensions}}) {
                    push(@found, $itemPath);
                    next;
                }
            }
        }
    }

    $dh->close();
    return @found;
}

sub GetAllFiles
{
    my $class = shift;
    my %args = (prefix => $ENV{DOCSRC_DIR},
                path => undef,
                extraExtensions => ["doc"],
                @_);

    my @all = $class->ScanDirectory(%args);

    my %all;
    my %files;
    foreach my $file (@all) {
        if ($file =~ s/\.(.*$)//) {
            my $ext = $1;

            # add file $file to %file
            unless (defined $files{$file}) {
                $files{$file} = [$ext];
            } else {
                push(@{$files{$file}}, $ext);
            }
        } else {
            # add directory $file to %all
            $all{$file} = 1;
        }
    }

    # collect different file types and add them to %all
    foreach my $file (keys %files) {
        my $ext = join(",", @{$files{$file}});
        $all{$file . "[" . $ext . "]"} = 1;
    }

    return sort(keys %all);
}

sub ExpandDir
{
    my $class = shift;
    my %args = (prefix => $ENV{DOCSRC_DIR},
                allDirs => undef,
                expand  => undef,
                @_);

    my @expand = split("/", $args{expand});

    my @all = ();
    foreach my $dir (@{$args{allDirs}}) {
        my @split = split("/", $dir);
        push(@all, \@split);
    }

    for (my $i=0; $i<=$#all; ++$i) {
        my $current = $all[$i];

        if ($#{$current} > $#expand+1) {
            delete @{$current}[$#expand+2..$#{$current}];
        }
    }

    for (my $j=1; $j<=$#expand+1; ++$j) {
        for (my $i=0; $i<=$#all; ++$i) {
            my $current = $all[$i];
            next if $j>$#{$current};

            unless (${$current}[$j-1] eq $expand[$j-1]) {
                delete @{$current}[$j..$#{$current}];
            }
        }
    }

    my %dirs;
    foreach my $dir (@all) {
        $dirs{join("/", @{$dir})} = 1;
    }

    return sort(keys %dirs);
}

sub MakeFileTree
{
    my $class = shift;
    my %args = (prefix => $ENV{DOCSRC_DIR},
                dirs => undef,
                @_);

    my %tree;

    foreach my $dir (@{$args{dirs}}) {
        my @items = split("/", $dir);
        my $current = \%tree;
        foreach my $item (@items) {
            if ($item =~ /\[[^\]]*\]$/) {
                $current->{$item} = "files:$dir";
                last;
            }

            unless (defined $current->{$item}) {
                $current->{$item} = {};
            }
            $current = $current->{$item};
        }

    }

    return %tree;
}

sub FileTreeTextDump
{
    my $class = shift;
    my %args = (fileTree => undef,
                indent   => 0,
                @_);

    foreach my $item (sort keys %{$args{fileTree}}) {
        if (${$args{fileTree}}{$item} =~ /^files/) {
            print " " x $args{indent} . "$item\n";
        }
    }
    foreach my $item (sort keys %{$args{fileTree}}) {
        unless (${$args{fileTree}}{$item} =~ /^files/) {
            print " " x $args{indent} . "$item\n";
            $class->FileTreeHtmlDump(fileTree => ${$args{fileTree}}{$item},
                                     indent   => 4+$args{indent});
        }
    }
}

sub FileTreeHtmlDump
{
    my $class = shift;
    my %args = (fileTree => undef,
                indent   => 0,
                lines    => undef,
                @_);

    my @items = sort keys %{$args{fileTree}};
    return if scalar(@items)==0;

    my $indent = " " x $args{indent};

    push(@{$args{lines}}, $indent . "<ul>\n");
    foreach my $item (@items) {
        my $css = "class=\"filetree\"";
        if (${$args{fileTree}}{$item} =~ /^files/) {
            push(@{$args{lines}}, $indent . "<li $css>$item</li>\n");
        }
    }
    foreach my $item (@items) {
        unless (${$args{fileTree}}{$item} =~ /^files/) {
            my $subTree = ${$args{fileTree}}{$item};
            my $css = "class=\"filetree\"";

            if (scalar(keys %{$subTree})!=0) {
                push(@{$args{lines}}, $indent . "<li $css>$item\n");
                $class->FileTreeHtmlDump(fileTree => $subTree,
                                         indent   => 4+$args{indent},
                                         lines    => $args{lines});
                push(@{$args{lines}}, $indent . "</li>\n");
            } else {
                push(@{$args{lines}}, $indent . "<li $css>$item</li>\n");
            }
        }
    }
    push(@{$args{lines}}, $indent . "</ul>\n");

}

sub CreateTree
{
    my $class = shift;
    my %args = (docEnv     => undef,
                allFiles   => undef,
                expand     => undef,
                documentId => undef,
                @_);

    my $docEnv = $args{docEnv};

    my @lines;
    push(@lines, $docEnv->filter(file => $ENV{SOURCEFILE_HEADER}));

    my @expanded = SourceFiles->ExpandDir(allDirs => $args{allFiles},
                                          expand  => $args{expand});
    my %tree = SourceFiles->MakeFileTree(dirs => \@expanded);
    SourceFiles->FileTreeHtmlDump(fileTree => \%tree, lines => \@lines);

    push(@lines, $docEnv->filter(file => $ENV{SOURCEFILE_FOOTER}));

    DocUtils->SaveLinebuffer(file => $docEnv->{outputFile},
                             linesRef => \@lines);
    if (defined $args{docId}) {
        Link->AddDocumentId(docEnv => $docEnv,
                            documentId => $args{documentId});
        print STDERR "[INFO]  ... filetree will have docId \"$args{docId}\"\n";
    }

#    for my $line (@lines) {
#        print $line;
#    }
}

1;
