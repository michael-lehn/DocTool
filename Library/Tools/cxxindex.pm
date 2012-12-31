package CxxIndex;
use strict;
use BerkeleyDB;
use MLDBM qw(BerkeleyDB::Btree);
use Data::Dumper;

BEGIN {
    die "[ERROR] \"DB_DIR\" not specified in configuration."
        unless defined $ENV{DB_DIR};

    DocUtils->Mkdir(path => $ENV{DB_DIR});

    our $db1 = tie our %CxxIndex, "MLDBM",
                    -Filename => "$ENV{DB_DIR}/CxxIndex.db",
                    -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/CxxIndex.db\"";

    our $db2 = tie our %CxxHeaderIndex, "MLDBM",
                    -Filename => "$ENV{DB_DIR}/CxxHeaderIndex.db",
                    -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/CxxHeaderIndex.db\"";

    our $db3 = tie our %CxxHeaderIndexTimestamp, "MLDBM",
                    -Filename => "$ENV{DB_DIR}/CxxHeaderIndexTimestamp.db",
                    -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/CxxHeaderIndexTimestamp.db\"";


    our $buffer_file = undef;
    our @buffer_lines;
}

sub IsUpToDate
{
    my $class = shift;
    my %args = (file    => undef,
                @_);

    unless ($CxxIndex::CxxHeaderIndexTimestamp{$args{file}}) {
        my $timestamp = DocUtils->GetTimestamp(file => $args{file});
        return undef;
    }

    my $time1 = DocUtils->GetTimestamp(file => $args{file});
    my $time2 = $CxxIndex::CxxHeaderIndexTimestamp{$args{file}};

    if ($time1>$time2) {
        return undef;
    }
    return 1;
}

sub Touch
{
    my $class = shift;
    my %args = (file    => undef,
                @_);

    my $timestamp = DocUtils->GetTimestamp(file => $args{file});
    $CxxIndex::CxxHeaderIndexTimestamp{$args{file}} = $timestamp;
}

sub CodeId2HtmlMark
{
    my $class = shift;
    my %args = (codeId    => undef,
                @_);
    my $mark = $args{codeId};
    $mark =~ s/#/\%23/g;
    $mark =~ s/\&/\&amp;/g;
    return $mark;
}

sub GetSnippet
{
    my $class = shift;
    my %args = (file    => undef,
                range   => undef,
                type    => undef,
                @_);

    if (!$CxxIndex::buffer_lines || ($args{file} ne $CxxIndex::buffer_file)) {
        $CxxIndex::buffer_file = $args{file};
        @CxxIndex::buffer_lines = DocUtils->LoadLinebuffer(file => $args{file},
                                                           removeNewlines => 1);
    }

    $args{range} =~ /(\d+):(\d+)-(\d+):(\d+)/;
    my $fromLine = $1;
    my $fromCol  = $2;
    my $toLine   = $3;
    my $toCol    = $4;

    --$fromLine;
    --$toLine;

    if ($args{type}) {
        return ["NAMESPACE"] if $args{type} =~ /^namespace/;
        for (my $line=$fromLine; $line<=$toLine; ++$line) {
            if ($CxxIndex::buffer_lines[$line] =~ /^\s*\{/) {
                $toLine = $line-1;
                last;
            }
            if ($CxxIndex::buffer_lines[$line] =~ /^\s*:/) {
                $toLine = $line-1;
                last;
            }
            if ($CxxIndex::buffer_lines[$line] =~ /\{/) {
                $toLine = $line;
                last;
            }
        }
    }

    my $offset = length($CxxIndex::buffer_lines[$fromLine]);
    for (my $line=$fromLine; $line<=$toLine; ++$line) {
        $CxxIndex::buffer_lines[$line] =~ /^(\s*)/;
        if ($offset>length($1)) {
            $offset = length($1);
        }
    }

    my @snippet;
    for (my $line=$fromLine; $line<=$toLine; ++$line) {
        my $str = substr($CxxIndex::buffer_lines[$line], $offset);
        if ($str =~ /^([^\{]*)\s*\{/) {
            $str = $1;
        }
        push(@snippet, $str);
    }

    if ($args{type}) {
        $snippet[$#snippet] .= ";";
    }

    return \@snippet;
}

sub ResetIndex
{
    my $class = shift;

    my $count = 0;
    $CxxIndex::db1->truncate($count);
    return $count;
}

sub ResetHeaderIndex
{
    my $class = shift;

    my $count = 0;
    $CxxIndex::db2->truncate($count);
    return $count;
}

sub ResetAll
{
    my $class = shift;

    $CxxIndex::db1->truncate();
    $CxxIndex::db2->truncate();
    $CxxIndex::db3->truncate();
}

sub Reset
{
    my $class = shift;
    my %args = (headerfile => undef,
                @_);

    die unless $args{headerfile};

    printf STDERR "[INFO] Removing all entries related to headerfile " .
                  "'$args{headerfile}' from CxxIndex database ...\n";


    my $headerindex = $CxxIndex::CxxHeaderIndex{$args{headerfile}};
    unless ($headerindex) {
        printf STDERR "[INFO] ... '$args{headerfile}' not found.\n";
        printf STDERR "[INFO] ... done.\n";
        return;
    }

    foreach my $key (keys %{$headerindex}) {
        my @items = keys %{$headerindex->{$key}};

        unless (exists $headerindex->{$key}->{id}) {
            die;
        }

        my $id = $headerindex->{$key}->{id};
        unless ($id) {
            printf "No 'id' for key='$key' in CxxHeaderIndex{$args{headerfile}}\n";
            printf "Found: \n";
            printf "Keys: ", keys %{$headerindex->{$key}}, "\n";
            printf "\n";
            foreach my $item (keys %{$headerindex->{$key}}) {
                printf "$item -> ";
                printf "$headerindex->{$key}->{$item}\n";
            }
            die;
        }
        printf STDERR "[INFO] ... deleting '$id' from CxxIndex database\n";
        delete $CxxIndex::CxxIndex{$id};
    }

    printf STDERR "[INFO] ... deleting '$args{headerfile}' from " .
                  "CxxHeaderIndex database\n";
    printf STDERR "[INFO] ... done.\n";
    delete $CxxIndex::CxxHeaderIndex{$args{headerfile}};
}

sub UpdateHeaderIndex
{
    my $class = shift;
    my %args = (docEnv           => undef,
                id               => undef,
                @_);
    my $id = $class->GetId(id => $args{id});

    my $headerfile       = $id->{headerfile};
    my $headerfile_range = $id->{headerfile_range};

    my $entry = $CxxIndex::CxxHeaderIndex{$headerfile};
    if (! exists $entry->{$headerfile_range}) {
        $entry->{$headerfile_range} = {}
    } else {
        unless ($entry->{$headerfile_range}->{id}) {
            printf STDERR "[ERROR] Unexpected error.\n";
            die;
        }
        if ($entry->{$headerfile_range}->{id} ne $args{id}) {
            printf STDERR "[ERROR] $headerfile:  $headerfile_range already " .
                          "referes to a different 'id'.\n";
            printf STDERR "[ERROR] Old: '$entry->{$headerfile_range}->{id}'\n";
            printf STDERR "[ERROR] New: '$args{id}'\n";
            die;
        }
    }

    $entry->{$headerfile_range} = {docEnv => $args{docEnv},
                                   id     => $args{id}};

    $CxxIndex::CxxHeaderIndex{$headerfile} = $entry;
}

sub GetHeaderIndex
{
    my $class = shift;
    my %args = (file  => undef,
                @_);

    if (! exists $CxxIndex::CxxHeaderIndex{$args{file}}) {
        print STDERR "[INFO] Header '$args{file}' not found in " .
                     "CxxHeaderIndex database.\n";
        return undef;
    }

    return $CxxIndex::CxxHeaderIndex{$args{file}};
}

sub AddId
{
    my $class = shift;
    my %args = (id               => undef,
                headerfile       => undef,
                headerfile_range => undef,
                sourcefile       => undef,
                sourcefile_range => undef,
                kind             => undef,
                type             => undef,
                keyword          => undef,
                @_);

    my $snippet = $class->GetSnippet(file  => $args{headerfile},
                                     range => $args{headerfile_range},
                                     type  => $args{type});

    my $entry = {headerfile       => $args{headerfile},
                 headerfile_range => $args{headerfile_range},
                 sourcefile       => $args{sourcefile},
                 sourcefile_range => $args{sourcefile_range},
                 kind             => $args{kind},
                 type             => $args{type},
                 keyword          => $args{keyword},
                 snippet          => $snippet};

#
#   Due to a bug in libclang an USR is not always unique.
#   (http://llvm.org/bugs/show_bug.cgi?id=13575)
#   In this case we add the compressed function declaration.
#
    my $string = "";
    for my $line (@{$snippet}) {
        if ($line =~ /^([^\(]*?)\w*\(/) {
            $string .= $1;
            last;
        } else {
            $string .= $line;
        }
    }
    my $compressed = $string;
    $compressed =~ s/[\s<>:]//g;
    $compressed =~ s/!/not/g;
    $compressed =~ s/\|\|/or/g;
    $compressed =~ s/\|/bor/g;
    $compressed =~ s/\&\&/and/g;
    $compressed =~ s/\&/band/g;
    $args{id} .= $compressed;

#
#   if this id is still not unique there is another problem
#
    if ($CxxIndex::CxxIndex{$args{id}}) {
        printf STDERR "[ERROR] In headerfile '$args{headerfile} " .
                      "($args{headerfile_range}):\n";
        my $snippetStr = join("\n", @{$snippet});
        printf STDERR "[ERROR] Id generated for \n$snippetStr\n not unique.\n";

        my $oldEntry = $CxxIndex::CxxIndex{$args{id}};
        printf STDERR "[ERROR] Previous definition in headerfile " .
                      "'$oldEntry->{headerfile} " .
                      "($oldEntry->{headerfile_range}):\n";

        die;
    }
    printf "[INFO] hack: '$string' was compressed to '$compressed'\n";
    printf "[INFO] new id is '$args{id}'\n";

    $CxxIndex::CxxIndex{$args{id}} = $entry;

#
#   CxxHeaderIndex must be updated AFTER the update of CxxIndex.
#
    $class->UpdateHeaderIndex(id => $args{id});
}

sub GetId
{
    my $class = shift;
    my %args = (id    => undef,
                @_);

    if (! exists $CxxIndex::CxxIndex{$args{id}}) {
        return undef;
    }

    return $CxxIndex::CxxIndex{$args{id}};
}

sub Demangle
{
    my $class = shift;
    my %args = (id      => undef,
                keyword => undef,
                @_);

    unless ($args{id} =~ s/^c://) {
        printf STDERR "[ERROR] id='$args{id}' does not match expected " .
                      "pattern\n";
        die "unexpected error\n";
    }

    my $result = {namespace      => undef,
                  class          => undef,
                  classId        => undef,
                  function       => undef,
                  classTemplates => undef,
                  funcTemplates  => undef
                 };

#
#   Get namespace(s)
#
    my @namespace;
    while ($args{id} =~ s/^\@N\@([^@]*)//) {
        push(@namespace, $1);
    }
    $result->{namespace} = join("::", @namespace);

#
#   Get class name
#
    if ($args{id} =~ s/^(\@[CS]\@([^@]*))//) {
        $result->{class}   = $2;
        $result->{classId} = "c:$1";
    }
    if ($args{id} =~ s/^(\@[CS]T>(\d+)[^@]*\@([^@]*))//) {
        $result->{class}          = $3;
        $result->{classTemplates} = $2;
        $result->{classId}        = "c:$1";
    }

#
#   Get function name
#
    if ($args{id} =~ /^\@F\@([^@#]*)#/) {
        $result->{function} = $1;
    }

    $args{keyword} = "?" unless $args{keyword};

    if ($args{id} =~ /^\@FT\@>(\d+)/) {
        $result->{function} = $args{keyword};
        $result->{funcTemplates} = $1;
    }
    return $result;
}

sub UpdateDB
{
    my $class = shift;
    my %args = (headerfile => undef,
                extension => [],
                @_);

    my $headerfile = $args{headerfile};
    my $path = DocUtils->Path(fullpath => $headerfile);
    my $basename = DocUtils->Basename(fullpath => $headerfile);

    #
    #   Search for sourcefiles with given basename
    #
    my %extension = (h   => 1,
                     tcc => 1,
                     cc  => 1);

    for (my $i=0; $i<=$#{$args{extension}}; ++$i) {
        my $key = $args{extension}->[$i];
        if ($key =~ /^-(.*)$/) {
            $key = $1;
            if (exists $extension{$key}) {
                delete $extension{$key};
            }
        } else {
            $key =~ s/^\+//;
            $extension{$key} = 1;
        }
    }

    printf STDERR "[INFO] Checking header and source files with " .
                  "basename '$basename' ...\n";

    my @sourcefile;
    foreach my $extension (sort keys %extension) {
        my $sourcefile = DocUtils->CreateFullpath(prefix    => $ENV{DOCSRC_DIR},
                                                  path      => $path,
                                                  basename  => $basename,
                                                  extension => $extension);
        if (-f $sourcefile) {
            push(@sourcefile, $sourcefile);
        }
    }
    if (scalar(@sourcefile)==0) {
        printf STDERR "[INFO] ... no header or sourcefile found\n";
        printf STDERR "[INFO] ... done.\n";
        return;
    }

    #
    #   Extract definitions that are declared in the header file.
    #

    my $DT_CXXINDEX = DocUtils->CreateFullpath(prefix   => $ENV{DOCTOOL},
                                               path     => "CxxTools",
                                               filename => "dt_cxxindex");

    my $indexfile = DocUtils->CreateFullpath(prefix   => $ENV{TMP_DIR},
                                             filename => "index");
    my $errorfile = DocUtils->CreateFullpath(prefix   => $ENV{TMP_DIR},
                                             filename => "error");
    my $exec = "mkdir -p $ENV{TMP_DIR};" .
               "cd $ENV{TMP_DIR};" .
               "rm -f $indexfile";
    my $exitCode = system($exec);
    die unless ($exitCode==0);

    foreach my $sourcefile (sort @sourcefile) {
        printf STDERR "[INFO] ... processing $sourcefile.\n";
        my $cmd = "$DT_CXXINDEX $ENV{CXXFLAGS} $sourcefile";

        printf STDERR "\$cmd = $cmd\n";

        $exec = "mkdir -p $ENV{TMP_DIR};" .
                "cd $ENV{TMP_DIR};" .
                "$cmd >> $indexfile 2> $errorfile";
        $exitCode = system($exec);
        my @error = DocUtils->LoadLinebuffer(file           => $errorfile,
                                             removeNewlines => 1);
        foreach my $error (@error) {
            printf STDERR "$error\n";
        }
        unless ($exitCode==0) {
            die "die";
        }
    }

    #
    #   Remove duplicates
    #
    my @index = DocUtils->LoadLinebuffer(file           => $indexfile,
                                         removeNewlines => 1);

    my %index;
    foreach my $key (@index) {
        $index{$key} = 1;
    }
    @index = keys %index;

    #
    #   For trimming the range of class definitions we need to read in the
    #   headerfile.
    #
    my @headerfile = DocUtils->LoadLinebuffer(file           => $headerfile,
                                              removeNewlines => 1);

    #
    #   Update database
    #
    printf STDERR "[INFO] Updating CxxIndex database with declarations " .
                  "found in '$headerfile'.\n";

    #   Remove all entries related to headerfile from the CxxIndex databases.
    CxxIndex->Reset(headerfile => $headerfile);

    foreach my $index (@index) {
        # /Users/lehn/libclang/func.h@10:1-15:2#namespace:foo
        # /Users/lehn/libclang/func.h@12:1-13:23->...
        $index =~ /^([^@]*)@(\d+:\d+-\d+:\d+)([#-])(.*)$/;
        my $headerfile       = $1;
        my $headerfile_range = $2;
        my $type             = $3;
        my $target           = $4;

        unless ($headerfile =~ /^$ENV{DOCSRC_DIR}(.*)$/) {
            # die "'$headerfile' not within '$ENV{DOCSRC_DIR}'";
            next;
        }
        $headerfile = $1;
        $headerfile =~ s/^\///;

        if ($type eq "-") {

            # >/Users/lehn/libclang/func.cc@8-12[8:function,c:@N@foo@F@function#&1I#]
            $target =~ /^>([^@]*)@(\d+-\d+)\[(\d+):([^\]]+)\],\[(.*)\]/;
            my $sourcefile       = $1;
            my $sourcefile_range = $2;
            my $kind             = $3;
            my $keyword          = $4;
            my $id               = $5;

            unless ($sourcefile) {
                printf STDERR "> $index\n";
                die;
            }

            unless ($sourcefile =~ /^$ENV{DOCSRC_DIR}(.*)$/) {
                # die "'$sourcefile' not within '$ENV{DOCSRC_DIR}'";
                next;
            }

            unless ($id) {
                # TODO: make this an error, not a warning
                printf STDERR "error in:  $index\n";
                # die;
                next;
            }
            $sourcefile = $1;
            $sourcefile =~ s/^\///;

            CxxIndex->AddId(id               => $id,
                            headerfile       => $headerfile,
                            headerfile_range => $headerfile_range,
                            sourcefile       => $sourcefile,
                            sourcefile_range => $sourcefile_range,
                            kind             => $kind,
                            keyword          => $keyword);
            printf STDERR "[INFO] ... added '$id' " .
                          "(declared in '$headerfile' $headerfile_range " .
                          "defined in '$sourcefile' $sourcefile_range) " .
                          "to CxxIndex database\n";
        } else {

            # class:D,c:@N@dummy@C@D
            $target =~ /^([^:]*):([^,]*),(.*)/;
            my $type    = $1;
            my $keyword = $2;
            my $id      = $3;

            # skip namespaces
            next if $type eq "namespace";

            # trim the range of class definitions
            my $found = undef;
            if ($type eq "class") {
                die unless $headerfile_range =~ /^(\d*):\d*-(\d*):\d*$/;
                my $from = $1;
                my $to = $2;
                for (my $i=$from; $i<=$to; ++$i) {
                    if ($headerfile[$i-1] =~ /\{/) {
                        $found = 1;
                        $to = $i;
                        last;
                    }
                }
                unless ($found) {
                    printf STDERR "[ERROR] Trouble with '$index'.\n";
                    die;
                }
                $headerfile_range = "${from}:0-${to}:0";
            }

            CxxIndex->AddId(id               => $id,
                            headerfile       => $headerfile,
                            headerfile_range => $headerfile_range,
                            type             => $type,
                            keyword          => $keyword);
            printf STDERR "[INFO] ... added '$id' " .
                          "('$headerfile' $headerfile_range) " .
                          "to CxxIndex database\n";
        }

    }

    printf STDERR "[INFO] ... done.\n";
}

sub UpdateCodeRefStubs
{
    my $class = shift;
    my %args = (headerfile => undef,
                @_);

    my $headerfile = $args{headerfile};

    die unless $headerfile =~ /^(.*)\.h$/;
    my $docfile = "$1.doc";

#
#   Only create/update the doc file if a CODEREF was changed or added. Or
#   became obsolete.
#
    my $updateRequired = undef;

#
#   Hash map %obsolete keeps track of obsolete snippet found in the doc file
#
    my $obsolete = {};

#
#   Array @output will contain the new doc file.
#
    my @output;

#
#   Hash map %found keeps track of processed code snippets.
#
    my %found;

#
#   If doc file already exists read it.  Check if it contains outdated
#   CodeRef boxes.
#
    if (-f $docfile) {
        print STDERR "[INFO] Updating '$docfile'.\n";
        my @docfile = DocUtils->LoadLinebuffer(file => $docfile,
                                               removeNewlines => 1);
        my $i = 0;
        while ($i<=$#docfile) {
            my $line = $docfile[$i];

            unless ($line =~ /^\s*\*--\[CODEREF\]-*\*\s*$/) {
                push(@output, $line);
                ++$i;
            } else {
                my @coderef;
                my $ln = $i+1;
                until ($line =~ /^\s*\*-*\*\s*$/) {
                    push(@coderef, $line);
                    ++$i;
                    die if ($i+1>$#docfile);
                    $line = $docfile[$i];
                }
                push(@coderef, $line);

                # read coderef id
                ++$i;
                $line = $docfile[$i];
                die unless $line =~ /^\s*\[.*\]\s*$/;
                while ($line =~ /^\s*\[.*\]\s*$/) {
                    push(@coderef, $line);
                    ++$i;
                    last if ($i>$#docfile);
                    $line = $docfile[$i];
                }

                my $found = CodeRef->CodeRef2Snippet(coderef => \@coderef);
                my $entry = CxxIndex->GetId(id => $found->{id});

                unless ($entry) {
                    print STDERR "[INFO] Line $ln:\n";
                    print STDERR "[INFO]     Found obsolete code for " .
                                 "'$found->{id}'.\n";
                    my $new = CodeRef->Snippet2CodeRef(id      => $found->{id},
                                                   snippet => $found->{snippet},
                                                   attribute => "O");
                    push(@output, @{$new});
                    $obsolete->{$ln} = $found->{id};
                    $updateRequired = 1;
                } else {
                    my $id   = $found->{id};
                    my $new  = $entry->{snippet};
                    my $old  = $found->{snippet};
                    my $attr = $found->{attribute};

                    unless (_CompareSnippets(snippet1 => $new, snippet2 => $old)) {
                        print STDERR "[INFO] Line $ln:\n";
                        print STDERR "[INFO]     Updated code snippet for '$id'.\n";
                        $attr = "M";
                        $updateRequired = 1;
                    } else {
#                       print STDERR "[INFO] Snippet of '$id' is up-to-date.\n";
                    }
                    my $coderef = CodeRef->Snippet2CodeRef(id        => $id,
                                                           snippet   => $new,
                                                           attribute => $attr);
                    push(@output, @{$coderef});
                    $found{$id} = 1;
                }
            }
        }
    } else {
        print STDERR "[INFO] ... creating '$docfile' with stubs " .
                     "for '$headerfile'.\n";
    }

    print STDERR "[INFO] ... checking if CODEREFs are missing.\n";

#
#   Read head file.  Check if some functions, classes, etc. are not yet
#   documented in the doc file.
#

    my $headerindex = CxxIndex->GetHeaderIndex(file => $headerfile);

#
#   Find ranges with relevant code and sort them.
#
    my @key = keys %{$headerindex};
    @key = sort {$a =~ /^(\d+):/; my $A = $1;
                  $b =~ /^(\d+):/; my $B = $1;
                  $A<=>$B}
           @key;

#
#   Get code-id and code-snippet
#
    my $foundNewId = undef;
    foreach my $key (@key) {
        my $id    = $headerindex->{$key}->{id};
        my $entry = CxxIndex->GetId(id => $id);

        if ($entry->{type}) {
            next if ($entry->{type} eq "namespace");
        }

        if ($found{$id}) {
            next;
        } else {
            unless ($foundNewId) {
                $foundNewId = 1;
                push(@output, "#" x 80);
                push(@output, "#");
                push(@output, "#  The following CODEREFs are automatically ".
                              "created stubs.");
                push(@output, "#");
                push(@output, "#" x 80, "", "");
                $updateRequired = 1;
            }
        }


        my $coderef = CodeRef->Snippet2CodeRef(id      => $id,
                                               snippet => $entry->{snippet});
        my $info    = _DefaultCodeRefInfo(id => $id,
                                          keyword => $entry->{keyword});

        print STDERR "[INFO] ... appending CODEREF stub for '$id'.\n";

        foreach my $line (@{$coderef}) {
            push(@output, $line);
        }
        push(@output, ("", $info, "", ""));

#       my $test = CodeRef->CodeRef2Snippet(coderef => $coderef);
#       print "id = $test->{id}\n";
#       for my $line (@{$test->{snippet}}) {
#           print "> $line\n";
#       }
    }


    if ($updateRequired) {
        DocUtils->SaveLinebuffer(file          => $docfile,
                                 linesRef      => \@output,
                                 appendNewLine => 1);
        print STDERR "[INFO] ... finishing '$docfile'.\n";
    } else {
        print STDERR "[INFO] ... '$docfile' is up-to-date.\n";
    }
    return $obsolete;
}

################################################################################
#                                                                              #
#  Auxiliary function generates some default description for classes,          #
#  methods and functions.                                                      #
#                                                                              #
################################################################################

sub _DefaultCodeRefInfo
{
    my %args = (id      => undef,
                keyword => undef,
                @_);

    my $info = CxxIndex->Demangle(id      => $args{id},
                                  keyword => $args{keyword});

    my $string = "";

    if ($info->{namespace}) {
        $string .= "    Defined in namespace `$info->{namespace}`.\n";
    }
    if ($info->{class}) {
        if (!$info->{function}) {
            $string .= "    Class $info->{class}";
            if ($info->{classTemplates}) {
                $string .= " with $info->{classTemplates} template parameters.";
            } else {
                $string .= ".";
            }
            $string .= "\n";
        } else {
            my $method = "Method `$info->{function}`";
            if ($info->{function} =~ /^operator(.*)/) {
                $method = "Operator `$1`";
            } elsif ($info->{function} =~ /^$info->{class}$/) {
                $method = "Constructor";
            } elsif ($info->{function} =~ /^$info->{class}</) {
                $method = "Constructor";
            } elsif ($info->{function} =~ /^~$info->{class}$/) {
                $method = "Destructor";
            }

            $string .= "    $method of class `$info->{class}`";
            if ($info->{classTemplates}) {
                $string .= " with $info->{classTemplates} template parameters.";
            } else {
                $string .= ".";
            }
            $string .= "\n";
        }
    } elsif ($info->{function}) {
        $string .= "    Function `$info->{function}`";
        if ($info->{funcTemplates}) {
            $string .= " with $info->{funcTemplates} template parameters.";
        } else {
            $string .= ".";
        }
        $string .= "\n";
    }

    return $string;
}

sub _CompareSnippets
{
    my %args = (snippet1 => undef,
                snippet2 => undef,
                @_);

    if ($#{$args{snippet1}} != $#{$args{snippet2}}) {
        return undef;
    }

    for (my $i=0; $i<=$#{$args{snippet1}}; ++$i) {
        my $snippet1 = $args{snippet1}->[$i];
        my $snippet2 = $args{snippet2}->[$i];

        $snippet1 =~ s/\s*$//;
        $snippet2 =~ s/\s*$//;

        if ($snippet1 ne $snippet2) {
            return undef;
        }
    }
    return 1;
}
1;
