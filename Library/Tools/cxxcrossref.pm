package CxxCrossRef;
use strict;
use BerkeleyDB;
use MLDBM qw(BerkeleyDB::Btree);
use Data::Dumper;

BEGIN {
    die "[ERROR] \"DB_DIR\" not specified in configuration."
        unless defined $ENV{DB_DIR};

    DocUtils->Mkdir(path => $ENV{DB_DIR});

    our $db1 = tie our %CxxCrossRef, "MLDBM",
                     -Filename => "$ENV{DB_DIR}/CxxCrossRef.db",
                     -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/CxxCrossRef.db\"";

    our $db2 = tie our %CxxCrossRefTimestamp, "MLDBM",
                     -Filename => "$ENV{DB_DIR}/CxxCrossRefTimestamp.db",
                     -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/CxxCrossRefTimestamp.db\"";

    our $db3 = tie our %CxxCrossRefDone, "MLDBM",
                     -Filename => "$ENV{DB_DIR}/CxxCrossRefDone.db",
                     -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/CxxCrossRefDone.db\"";

    our $buffer_file = undef;
    our @buffer_lines;
}

sub MarkDone
{
    my $class = shift;
    my %args = (entryline => undef,
                @_);

    $CxxCrossRef::CxxCrossRefDone{$args{entryline}} = 1;
}

sub IsDone
{
    my $class = shift;
    my %args = (entryline => undef,
                @_);

    return $CxxCrossRef::CxxCrossRefDone{$args{entryline}};
}


sub IsUpToDate
{
    my $class = shift;
    my %args = (file    => undef,
                @_);

    unless ($CxxCrossRef::CxxCrossRefTimestamp{$args{file}}) {
        my $timestamp = DocUtils->GetTimestamp(file => $args{file});
        return undef;
    }

    my $time1 = DocUtils->GetTimestamp(file => $args{file});
    my $time2 = $CxxCrossRef::CxxCrossRefTimestamp{$args{file}};

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
    $CxxCrossRef::CxxCrossRefTimestamp{$args{file}} = $timestamp;
}

sub ResetAll
{
    my $class = shift;

    my $count;
    $CxxCrossRef::db1->truncate($count);
    $CxxCrossRef::db2->truncate($count);
    $CxxCrossRef::db3->truncate($count);
}

sub Reset
{
    my $class = shift;
    my %args = (file => undef,
                @_);

    my $file = $args{file};
    unless ($file) {
        die "\$args{file} not defined.\n";
    }
    unless ($CxxCrossRef::CxxCrossRef{$file}) {
        return;
    }
    delete $CxxCrossRef::CxxCrossRef{$file};
}

sub GetCrossRef
{
    my $class = shift;
    my %args = (file      => undef,
                @_);

    my $file = $args{file};
    if (! exists $CxxCrossRef::CxxCrossRef{$file}) {
        return undef;
    }
    return $CxxCrossRef::CxxCrossRef{$file};
}

sub AddCrossRef
{
    my $class = shift;
    my %args = (file      => undef,
                file_line => undef,
                file_col1 => undef,
                file_col2 => undef,
                dest      => undef,
                dest_line => undef,
                kind      => undef,
                keyword   => undef,
                @_);

    my $file = $args{file};
    my $line = $args{file_line};
    my $col  = $args{file_col1};

#    print STDERR "[INFO] Add '$args{keyword}'" .
#                 "from $file ($line:$col). Ref = " . ref($args{dest}) .
#                 " dest = $args{dest}\n";
#

    if (! exists $CxxCrossRef::CxxCrossRef{$file}) {
        $CxxCrossRef::CxxCrossRef{$file} = {};
    }
    my $fileEntry = $CxxCrossRef::CxxCrossRef{$file};

    if (! exists $fileEntry->{$line}) {
        $fileEntry->{$line} = {};
    }
    my $lineEntry = $fileEntry->{$line};

    if (exists $lineEntry->{$col}) {
        my $old = $lineEntry->{$col};
        if (($old->{toCol} != $args{file_col2})
         || ($old->{kind} ne $args{kind})
         || ($old->{keyword} ne $args{keyword}))
        {
            print STDERR "\$old->{toCol} = $old->{toCol}, ".
                         "\$args{file_col2} = $args{file_col2}\n";
            print STDERR "\$old->{kind} = $old->{kind}, ".
                         "\$args{kind} = $args{kind}\n";
            print STDERR "\$old->{keyword} = $old->{keyword}, ".
                         "\$args{keyword} = $args{keyword}\n";
            printf STDERR "Hope the best ... \n";
            # die;
        }
        if (ref($old->{dest}) ne "ARRAY") {
            if (($old->{dest} ne $args{dest}) ||
                ($old->{destLine} != $args{dest_line}))
            {
                print STDERR "\$old->{dest} = $old->{dest}, ".
                             "\$args{dest} = $args{dest}\n";
                print STDERR "\$old->{destLine} = $old->{destLine}, ".
                             "\$args{destLine} = $args{dest_line}\n";
                printf STDERR "Hope the best ... \n";
                # die;
            }
        } else {
            my @oldDest = @{$old->{dest}};
            my @newDest = @{$args{dest}};
            my @oldDestLine = @{$old->{destLine}};
            my @newDestLine = @{$args{dest_line}};
            if ((scalar(@oldDest) != scalar(@newDest))
             || (scalar(@oldDestLine) != scalar(@newDestLine)))
            {
                print "\@oldDest = @oldDest\n";
                print "\@newDest = @newDest\n";
                print "\@oldDestLine = @oldDestLine\n";
                print "\@newDestLine = @newDestLine\n";
                printf STDERR "Hope the best ... \n";
                # die;
            } else {
                for (my $i=0; $i<=$#oldDest; ++$i) {
                    print "\$oldDest[$i] = '$oldDest[$i]'\n";
                    print "\$newDest[$i] = '$newDest[$i]'\n";

                    print "\$oldDestLine[$i] = '$oldDestLine[$i]'\n";
                    print "\$newDestLine[$i] = '$newDestLine[$i]'\n";

                    die if $oldDest[$i] ne $newDest[$i];
                    die if $oldDestLine[$i] ne $newDestLine[$i];
                }
            }
        }
        return;
    }

    $lineEntry->{$col} = {toCol    => $args{file_col2},
                          dest     => $args{dest},
                          destLine => $args{dest_line},
                          kind     => $args{kind},
                          keyword  => $args{keyword}};


    $CxxCrossRef::CxxCrossRef{$file} = $fileEntry;
}

sub _AdjustCrossRef
{
    my $class = shift;
    my %args = (file       => undef,
                file_range => undef,
                kind       => undef,
                keyword    => undef,
                @_);

    if ((!$CxxCrossRef::buffer_file)
     || ($args{file} ne $CxxCrossRef::buffer_file))
    {
        $CxxCrossRef::buffer_file = $args{file};
        @CxxCrossRef::buffer_lines = DocUtils->LoadLinebuffer(file => $args{file},
                                                              removeNewlines => 1);
    }

    die unless $args{file_range} =~ /^(\d*):(\d*)-(\d*):(\d*)$/;
    my $fromLine = $1-1;
    my $fromCol  = $2-1;
    my $toLine   = $3-1;
    my $toCol    = $4-1;

    my $keyword = $args{keyword};
    my $kind    = $args{kind};

    # CXCursor_TypeRef
    if ($kind==43) {
        $keyword =~ s/^enum\s*//;
    }

    # CXCursor_CXXMethod
    # CXCursor_FunctionTemplate
    if ($kind==21
     || $kind==30)
    {
        if ($keyword =~ /^operator/) {
            $keyword = "operator";
        }
    }

    # CXCursor_DeclRefExpr
    if ($kind==101) {
        if ($keyword =~ /^operator(.*)/) {
            $keyword = $1;
        }
    }

    my $found = substr($CxxCrossRef::buffer_lines[$fromLine],
                       $fromCol, $toCol-$fromCol);

    # CXCursor_OverloadedDeclRef
    if ($kind==49 && $keyword =~ /^operator/ && $found =~ /^\W*$/) {
#
#       Skipp stuff like A*B where '*' could refer to any overloaded
#       variant of 'operator*' ...
#
        return undef;
    }

    # CXCursor_OverloadedDeclRef
    if ($kind==49 && $found eq "operator") {
        $keyword = "operator";
        $toCol   = $fromCol + length($keyword);

        $found = substr($CxxCrossRef::buffer_lines[$fromLine],
                       $fromCol, $toCol-$fromCol);
    }

    if ($keyword ne $found) {
        print "keyword = '$keyword'\n";
        print "found   = '$found'\n";
        print "line    = '$CxxCrossRef::buffer_lines[$fromLine]'\n";
        print "kind    = '$kind'\n";
        print "SKIPPING.\n\n";
        # die;
        return undef;
    }

    return {file_line => $fromLine,
            file_col1 => $fromCol,
            file_col2 => $toCol,
            keyword   => $keyword};
}

sub UpdateDB
{
    my $class = shift;
    my %args = (file => undef,
                @_);

    my $fullpath = DocUtils->CreateFullpath(prefix   => $ENV{DOCSRC_DIR},
                                            filename => $args{file});

    my $crossref = DocUtils->CreateFullpath(prefix   => $ENV{TMP_DIR},
                                            filename => "crossref");
    my $err = DocUtils->CreateFullpath(prefix   => $ENV{TMP_DIR},
                                       filename => "err");

    my $DT_CROSSREF = DocUtils->CreateFullpath(prefix   => $ENV{DOCTOOL},
                                               path     => "CxxTools",
                                               filename => "dt_crossref2");

    my $exec = "mkdir -p $ENV{TMP_DIR}; cd $ENV{TMP_DIR}; rm -f $crossref";
    my $exitCode = system($exec);
    die unless ($exitCode==0);

    my $cmd = "$DT_CROSSREF $ENV{CXXFLAGS} $fullpath $ENV{DOCSRC_DIR}";
    $exec = "mkdir -p $ENV{TMP_DIR}; cd $ENV{TMP_DIR}; $cmd >$crossref 2>$err";
    printf STDERR "[INFO] Executing: $cmd\n";
    $exitCode = system($exec);

    my @error = DocUtils->LoadLinebuffer(file           => $err,
                                         removeNewlines => 1);
    foreach my $error (@error) {
        printf STDERR "$error\n";
    }
    unless ($exitCode==0) {
        # die "die";
        printf STDERR "\n[WARNING] Skipping '$args{file}'\n\n";
    }

    my @crossref = DocUtils->LoadLinebuffer(file           => $crossref,
                                            removeNewlines => 1);
#
#   Remove duplicates
#
    my %crossref;
    foreach my $key (@crossref) {
        $crossref{$key} = 1;
    }
    @crossref = keys %crossref;

#
#   Remove all entries related to headerfile from the CxxIndex databases.
#
#$class->Reset(file => $args{file});

#
#   Add cross references to database
#
    my $skippedData = undef;
    foreach my $data (sort @crossref) {
        if ($class->IsDone(entryline => $data)) {
            $skippedData = 1;
            # printf STDERR ".";
            next;
        } else {
            if ($skippedData) {
                # printf STDERR "\n";
                $skippedData = undef;
            }
            printf STDERR "[INFO] Processing: $data\n";
        }

        if ($data =~ /^([^@]+)@([\d:-]*)->([^@]+)@([^@]+)\[(\d*):(.*)\]$/) {
            my $file       = $1;
            my $file_range = $2;
            my $dest       = $3;
            my $dest_line  = $4;
            my $kind       = $5;
            my $keyword    = $6;

            unless ($file =~ /^$ENV{DOCSRC_DIR}(.*)$/) {
                die "'$file' not within '$ENV{DOCSRC_DIR}'";
                next;
            }
            $file = $1;
            $file =~ s/^\///;

            unless ($dest =~ /^$ENV{DOCSRC_DIR}(.*)$/) {
                die "'$dest' not within '$ENV{DOCSRC_DIR}'";
                # next;
            }
            $dest = $1;
            $dest =~ s/^\///;

            $keyword =~ s/<.*>$//;
            $keyword =~ s/^.*:://;

            my $entry = $class->_AdjustCrossRef(file       => $file,
                                                file_range => $file_range,
                                                kind       => $kind,
                                                keyword    => $keyword);

            unless ($entry) {
                # printf "Skipping crossref entry ...\n";
                $class->MarkDone(entryline => $data);
                next;
            }

            $class->AddCrossRef(file      => $file,
                                file_line => $entry->{file_line},
                                file_col1 => $entry->{file_col1},
                                file_col2 => $entry->{file_col2},
                                dest      => $dest,
                                dest_line => $dest_line,
                                kind      => $kind,
                                keyword   => $entry->{keyword});
            $class->MarkDone(entryline => $data);
        } elsif ($data =~ /^([^@]+)@([\d:-]*)=>\[(\d+):([^:]*):(.*)\]$/) {
            my $file       = $1;
            my $file_range = $2;
            my $kind       = $3;
            my $keyword    = $4;
            my $destlist   = $5;

            unless ($file =~ /^$ENV{DOCSRC_DIR}(.*)$/) {
                die "'$file' not within '$ENV{DOCSRC_DIR}'";
                next;
            }
            $file = $1;
            $file =~ s/^\///;

            my %dest;
            while ($destlist =~ /^([^@]*)@(\d*),?(.*)/) {
                if (! exists $dest{$1}) {
                    $dest{$1} = [];
                }
                push(@{$dest{$1}}, $2);
                $destlist = $3;
            }

            my @dest;
            my @destLine;
            foreach my $dest (sort keys %dest) {
                foreach my $destLine (sort {$a <=> $b} @{$dest{$dest}}) {
                    if ($dest =~ /^$ENV{DOCSRC_DIR}\/?(.*)$/) {
                        $dest = $1;
                    } else {
                        if (index($dest, "\[external\]")==-1) {
#die "'$dest' not within '$ENV{DOCSRC_DIR}'";
                            # next;
                        }
                    }
                    printf STDERR "-> $dest\n";
                    push(@dest, $dest);
                    push(@destLine, $destLine);
                }
            }

            my $entry = $class->_AdjustCrossRef(file       => $file,
                                                file_range => $file_range,
                                                kind       => $kind,
                                                keyword    => $keyword);

            unless ($entry) {
                # printf "Skipping crossref entry ...\n";
                $class->MarkDone(entryline => $data);
                next;
            }

            $class->AddCrossRef(file      => $file,
                                file_line => $entry->{file_line},
                                file_col1 => $entry->{file_col1},
                                file_col2 => $entry->{file_col2},
                                dest      => \@dest,
                                dest_line => \@destLine,
                                kind      => $kind,
                                keyword   => $entry->{keyword});
            $class->MarkDone(entryline => $data);

            for (my $i=0; $i<=$#dest; ++$i) {
                my $line = sprintf("%6d", $destLine[$i]);
                printf "$line ($dest[$i])\n";
            }
        }
    }
    if ($skippedData) {
        printf STDERR "\n";
        $skippedData = undef;
    }

}

1;
