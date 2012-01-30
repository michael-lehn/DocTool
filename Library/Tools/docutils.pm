package DocUtils;

use strict;
use DirHandle;
use FileHandle;
use Encode;


######
##
## SYSTEM TOOLS
##
######

sub Mkdir
{
    my $class = shift;
    my %args = (path => undef,
                @_);

    system ("mkdir -p $args{path}");
}

sub Copy
{
    my $class = shift;
    my %args = (file => undef,
                from => undef,
                to => undef,
                filename => undef,
                newFilename => undef,
                @_);

    unless (defined $args{file}) {
        $args{file} = "$args{from}/$args{filename}";
    }
    unless (defined $args{from}) {
        $args{from} = DocUtils->Path(fullpath => $args{file});
        $args{filename} = DocUtils->Filename(fullpath => $args{file});
    }
    DocUtils->Mkdir(path => $args{to});
    unless (defined $args{newFilename}) {
        $args{newFilename} = $args{filename};
    }

    system("cp $args{file} $args{to}/$args{newFilename}");
    system("chmod ug+w $args{to}/$args{newFilename}");
}

sub Install
{
    my $class = shift;
    my %args = (file => undef,
                from => undef,
                to => undef,
                filename => undef,
                newFilename => undef,
                @_);

    unless (defined $args{file}) {
        $args{file} = "$args{from}/$args{filename}";
    }
    unless (defined $args{from}) {
        $args{from} = DocUtils->Path(fullpath => $args{file});
        $args{filename} = DocUtils->Filename(fullpath => $args{file});
    }
    unless (defined $args{newFilename}) {
        $args{newFilename} = $args{filename};
    }

    unless (DocUtils->IsNewerThan(file1 => $args{file},
                                  file2 => "$args{to}/$args{newFilename}"))
    {
        return undef;
    }

    DocUtils->Copy(%args);
    return 1;
}


######
##
## HANDLING OF FILENAMES, PATHS, ...
##
######

sub _RelativePath
{
    my $class = shift;
    my %args = (
        filename => undef,
        fromPath => undef,
        toPath => undef,
        @_);

    die "RelativePath: you have to pass 'filename'"
        unless defined $args{filename};
    die "RelativePath: you have to pass 'fromPath'"
        unless defined $args{fromPath};
    die "RelativePath: you have to pass 'toPath'"
        unless defined $args{toPath};

    $args{fromPath} =~ s/^\///;
    $args{fromPath} =~ s/\/$//;
    $args{toPath} =~ s/^\///;
    $args{toPath} =~ s/\/$//;

    my @fromPath = split "/", $args{fromPath};
    my @toPath = split "/", $args{toPath};

    my $commonSubPath = 1;
    my @relPathUp;
    my @relPathDown;
    while (1) {
        my $from = shift @fromPath;
        my $to = shift @toPath;

        if ((defined $commonSubPath) && (defined $from) && (defined $to)) {
            next if ($from eq $to);
        }
        $commonSubPath = undef;

        if (defined $from) {
            push(@relPathUp, "..");
        }

        if (defined $to) {
            push(@relPathDown, $to);
        }

        unless ((defined $from) || (defined $to)) {
            last;
        }
    }
    push(@relPathDown, $args{filename});
    push(@relPathUp, @relPathDown);

    return join("/", @relPathUp);
}

sub RelativePath
{
    my $class = shift;
    my %args = (
        currentPath => undef,
        removeDestinationPrefix => "",
        destinationPath => undef,
        @_);

    die "RelativePath: you have to pass 'destinationPath'"
        unless defined $args{destinationPath};

    unless (defined $args{currentPath}) {
        $args{currentPath} = "";
    }

    $args{currentPath} =~ s/\/$//;
    $args{removeDestinationPrefix} =~ s/\/$//;
    $args{destinationPath} =~ s/\/$//;

    my $path = $args{destinationPath};
    if (defined $args{removeDestinationPrefix}) {
        $path =~ s/$args{removeDestinationPrefix}//;
    }
    my $rel = "";
    foreach my $item (split("/", $args{currentPath})) {
        $rel = $rel . "../";
    }
    if ($rel eq "") {
        $rel = "./";
    }
    $rel = $rel . $path;
    $rel =~ s/\/$//;
    $rel =~ s/\/\//\//g;
    return $rel;
}

sub CreateFullpath
{
    my $class = shift;
    my %args = (
        prefix => undef,
        path => undef,
        filename => undef,
        basename => undef,
        extension => undef,
        newExtension => undef,
        @_);

    die "CreateFullpath: Either pass basename or filename. Not both."
        if (defined($args{basename}) && defined($args{filename}));

    my $fullpath = "";
    if ( $args{prefix}) {
        $fullpath = $args{prefix} . "/";
    }

    if (defined $args{path}) {
        $fullpath .= $args{path} . "/";
    }

    if (defined $args{basename}) {
        die "createFullpath: If you pass basename also pass extension."
            unless defined $args{extension};
        $fullpath = $fullpath . $args{basename} . "." . $args{extension};
    }

    if (defined $args{filename}) {
        $fullpath = $fullpath . $args{filename};
    }

    if (defined $args{newExtension}) {
        $fullpath =~ s/\.[^.]*$/\.$args{newExtension}/;
    }

    $fullpath =~ s/\/\//\//g;
    $fullpath =~ s/\/*$//;

    return $fullpath;
}

sub Path
{
    my $class = shift;
    my %args = (fullpath => undef,
                @_);

    if (($args{fullpath}) && ($args{fullpath}=~/\//)) {
        $args{fullpath} =~ s/\/[^\/]*$//;
        return $args{fullpath};
    }
    return "";
}

sub Filename
{
    my $class = shift;
    my %args = (fullpath => undef,
                @_);

    $args{fullpath} =~ s/.*\///;
    return $args{fullpath};
}

sub Basename
{
    my $class = shift;
    my %args = (fullpath => undef,
                @_);

    $args{fullpath} =~ s/.*\///;
    $args{fullpath} =~ s/\.[^.]*$//;
    return $args{fullpath};
}

sub Extension
{
    my $class = shift;
    my %args = (fullpath => undef,
                @_);

    $args{fullpath} =~ s/.*\.//;
    return $args{fullpath};
}

sub IsNewerThan
{
    my $class = shift;
    my %args = (file1 => undef,
                file2 => undef,
                @_);

    unless (-e $args{file2}) {
        return 1;
    }

    my $time1 = (stat "$args{file1}")[9];
    my $time2 = (stat "$args{file2}")[9];

    if ($time1 > $time2) {
        return 1;
    }
    return undef;
}

sub FindFiles
{
    my $class = shift;
    my %args = (path => undef,
                pattern => undef,
                @_);

    my $dh = DirHandle->new($args{path})
             || die ("cannot open dir: $args{path}");
    my @filelist;
    while (my $file = $dh->read()) {
        next if (($file eq ".") || ($file eq ".."));
        next if ($file =~ /^\./);
        push(@filelist, $file) if $file =~ /$args{pattern}/;

        my $subdir = join("/", $args{path}, $file);
        if (-d $subdir) {
            my $relsubdir = $file;
            foreach my $file ($class->FindFiles(path => $subdir,
                                                pattern => $args{pattern}))
            {
                push(@filelist, join("/", $relsubdir, $file));
            }
        }
    }
    return @filelist;
}

sub ParentDirectory
{
    my $class = shift;
    my %args = (path => undef,
                @_);

    my @paths = split("/", $args{path});
    pop(@paths);
    return join("/", @paths);
}

sub ParentDirectories
{
    my $class = shift;
    my %args = (path => undef,
                @_);

    my @paths = split("/", $args{path});

    my @dirs;
    for (my $i=0; $i<$#paths; ++$i) {
        push(@dirs, join("/", @paths[0..$i]));
    }
    return @dirs;
}

sub ExtractDirectories
{
    my $class = shift;
    my %args = (files                => undef,
                allParentDirectories => 0,
                @_);

    my %dirs;
    foreach my $file (@{$args{files}}) {
        my $dir = $class->Path(fullpath => $file);
        next if defined $dirs{$dir};

        $dirs{$dir} = 1;

        if ($args{allParentDirectories}) {
            foreach my $parent ($class->ParentDirectories(path => $dir)) {
                $dirs{$parent} = 1;
            }
        }
    }
    return sort keys %dirs;
}

######
##
## FILE IO HANDLING
##
######

sub SaveLinebuffer
{
    my $class = shift;
    my %args = (file => undef,
                linesRef => undef,
                appendNewLine => undef,
                @_);

    DocUtils->Mkdir(path => DocUtils->Path(fullpath => $args{file}));
    my $fh = FileHandle->new("> $args{file}") || die "cannot open $args{file}";
    foreach my $line (@{$args{linesRef}}) {
        print $fh "$line";
        print $fh "\n" if $args{appendNewLine};
    }
    $fh->close();
}

sub LoadLinebuffer
{
    my $class = shift;
    my %args = (file => undef,
                silent => undef,
                prefix => undef,
                removeTrailingSpaces => undef,
                removeNewlines => undef,
                @_);

    if ($args{prefix}) {
        $args{file} = $args{prefix} . "/" . $args{file};
    }

    my $fh = FileHandle->new("< $args{file}");

    unless (defined $fh) {
        die "[ERROR] can not open \"$args{file}\" for reading.\n";
        return;
    }

    my @linebuffer;
    while (my $line = <$fh>) {
        $line = Encode::decode("utf-8", $line);
        if ($args{removeNewlines}) {
            chomp($line);
        }
        if ($args{removeTrailingSpaces}) {
            $line =~ s/^(.*?)\s*$/$1/;
        }
        push(@linebuffer, $line);
    }
    $fh->close();
    return @linebuffer
}


######
##
## TEXT & CONTENT HANDLING
##
######

sub ConvertSonderzeichen
{
    my $class = shift;
    my %args = (lineRef => undef,
                @_);

    my $line = $args{lineRef};
    $$line =~ s/([^\\])\&/$1&amp;/g;
    $$line =~ s/\\\&/&/g;
    while ($$line =~ s/(\[[^]]*)<([^]]*\])/$1&lt;$2/g) {}
    while ($$line =~ s/(\[[^]]*)>([^]]*\])/$1&gt;$2/g) {}
}

sub ConvertTT
{
    my $class = shift;
    my %args = (lineRef => undef,
                @_);

    my $line = $args{lineRef};
    $$line =~ s/\[([^\]]*)\]/<tt>$1<\/tt>/g;
}


sub ExpandVariables
{
    my $class = shift;
    my %args = (linesRef => undef,
                varsRef => \%ENV,
                @_);
    my %VARS = %{$args{varsRef}};

    my @linebuffer;
    my $skip = undef;
    foreach my $line (@{$args{linesRef}}) {
        if ($line =~ /#FI_.*_#/) {
            $skip = undef;
            next;
        }
        next if $skip;
        if ($line =~ /#IF_([^#]+)_#/) {
            my $var = $1;
            unless ($VARS{$var}) {
                $skip=1;
            } else {
            }
            next;
        }

        while ($line =~ /#_([^#]+)_#/) {
            my $var = $1;
            my $value = (defined $VARS{$var}) ? $VARS{$var} : ""; 
            $line =~ s/#_${var}_#/$value/;
        }
        push(@linebuffer, $line);
    }
    return @linebuffer;
}

######
##
## MANAGE CONFIGURARTION
##
######

sub EvalConfigFile
{
    my $class = shift;
    my %args = (file => undef,
                varsRef => \%ENV,
                @_);

    my $fh = FileHandle->new("< $args{file}");
    if ($fh) {
        print STDERR "[INFO] evaluating \"$args{file}\".\n";
    } else {
        print STDERR "[INFO] could not find \"$args{file}\". Skipping.\n";
        return;
    }

    my %var;
    while (my $line=$fh->getline()) {
        # remove comments
        $line =~ s/[^\\]#.*//;
        $line =~ s/^#.*//;

        if ($line =~ /\s*(\S*)=(.*)$/) {
            $var{$1} = DocUtils->ReplaceShellVars(line => $2,
                                                  varsRef => $args{varsRef});
            # export the variable with its expanded value
            ${$args{varsRef}}{$1} = $var{$1};

            # print "[DEBUG] ->$1=$var{$1};\n";
        }
    }
    $fh->close();
    return %var;
}

sub ReplaceShellVars
{
    my $class = shift;
    my %args = (line => undef,
                varsRef => \%ENV,
                @_);
    my %VARS = %{$args{varsRef}};

    #replace simple variables like "${PWD}"
    #   but not nested like ${BLA${BLUB}}
    #   or variables like ${DUMMY:-${PWD}}
    while ($args{line} =~ /\$\{([^}{:]*)\}/) {
        my $var = $1;
        my $value = $VARS{$var};
        $args{line} =~ s/\$\{$var\}/$value/g;
    }
    while ($args{line} =~ /\$\{([^}:]*):-([^}]*)\}/) {
        my $var = $1;
        my $default = $2;

        my $value = $VARS{$var};
        $value = $default unless $value;
        $args{line} =~ s/\$\{$var:-$default\}/$value/g;
    }
    while ($args{line} =~ /`([^`]*)`/) {
        my $cmd = FileHandle->new("$1 |");
        my $value = <$cmd>;
        chomp $value;
        $cmd->close();
        $args{line} =~ s/`([^`]*)`/$value/;
    }
    $args{line} =~ s/^\"(.*)\"$/$1/;
    return $args{line};
}

1;
