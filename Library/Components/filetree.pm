package Filetree;
use strict;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {directory      => undef,
                 allFiles       => undef,

                 filesTrimmed   => undef,
                 fileTree       => undef,
                 @_};
    die unless defined($self->{directory}) && defined($self->{allFiles});

    bless ($self, $class);

    $self->_trimmDirs;
    $self->_fileTree;
    return $self;
}

sub _trimmDirs
{
    my $self = shift;

    my @directory = split("/", $self->{directory});

    my @all = ();
    foreach my $dir (@{$self->{allFiles}}) {
        my @split = split("/", $dir);
        push(@all, \@split);
    }

    for (my $i=0; $i<=$#all; ++$i) {
        my $current = $all[$i];

        if ($#{$current} > $#directory+1) {
            delete @{$current}[$#directory+2..$#{$current}];
        }
    }

    for (my $j=1; $j<=$#directory+1; ++$j) {
        for (my $i=0; $i<=$#all; ++$i) {
            my $current = $all[$i];
            next if $j>$#{$current};

            unless (${$current}[$j-1] eq $directory[$j-1]) {
                delete @{$current}[$j..$#{$current}];
            }
        }
    }

    my %dirs;
    foreach my $dir (@all) {
        $dirs{join("/", @{$dir})} = 1;
    }
    $self->{filesTrimmed} = [sort keys %dirs];
}

sub _fileTree
{
    my $self = shift;

    my %tree;

    foreach my $dir (@{$self->{filesTrimmed}}) {
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

    $self->{fileTree} = \%tree;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    $self->FileTreeHtmlDump(fileTree => $self->{fileTree},
                            html     => $args{html});
}

sub FileTreeHtmlDump
{
    my $class = shift;
    my %args = (fileTree => undef,
                html     => undef,
                path     => undef,
                @_);

    my @items = sort keys %{$args{fileTree}};
    return if scalar(@items)==0;

    my $docEnv = $args{html}->{docEnv};
    my $css = "class=\"filetree\"";

    $args{html}->addLine(line => "<ul $css>");
    $args{html}->incrementIndentLevel();

    foreach my $item (@items) {
        if (${$args{fileTree}}{$item} =~ /^files/) {
            $item =~ /(.*)\[(.*)\]/;
            my $file = $1;
            my @ext  = split(",", $2);

            my $mark = DocUtils->CreateFullpath(path      => $args{path},
                                                filename  => $file);
            $mark = "<a name=\"$mark\"></a>";

            my @links;
            my $listItem = $file;
            foreach my $ext (sort @ext) {
                my $docId = DocUtils->CreateFullpath(path      => $args{path},
                                                     basename  => $file,
                                                     extension => $ext);
                $docId = "file:" . $docId;

                my $link = Html->MakeLink(fromDocEnv => $docEnv,
                                          toDocEnv => $docId);
                if ($ext eq "doc") {
                    $listItem = "<a href=\"$link\">$file</a>";
                    next;
                }
                $link = "<a href=\"$link\">$ext</a>";
                push(@links, $link);
            }

            if (scalar(@links)>0) {
                $listItem = $listItem . " [ " . join (", ", @links) . " ]";
            }
            $args{html}->addLine(line => "<li $css>$mark$listItem</li>");
        }
    }
    foreach my $item (@items) {
        unless (${$args{fileTree}}{$item} =~ /^files/) {
            my $currentPath = DocUtils->CreateFullpath(prefix => $args{path},
                                                       path   => $item);
            my $mark = "<a name=\"$currentPath\"></a>";
            my $subTree = ${$args{fileTree}}{$item};
            my $css = "class=\"filetree\"";

            if (scalar(keys %{$subTree})!=0) {
                my $parent = DocUtils->ParentDirectory(path => $currentPath);
                my $link = Html->MakeLink(fromDocEnv => $docEnv,
                                          toDocEnv => "dir:$parent/");
                $link = "<a href=\"$link\">$item</a>";

                $args{html}->addLine(line => "<li $css>$mark$link");
                $class->FileTreeHtmlDump(fileTree => $subTree,
                                         html     => $args{html},
                                         path     => $currentPath);
                $args{html}->addLine(line => "</li>");
            } else {
                my $link = Html->MakeLink(fromDocEnv => $docEnv,
                                          toDocEnv => "dir:$currentPath/");
                $link = "<a href=\"$link\">$item/</a>";
                $args{html}->addLine(line => "<li $css>$mark$link</li>");
            }
        }
    }

    $args{html}->decreaseIndentLevel();
    $args{html}->addLine(line => "</ul>");
}

sub CompressFileList
{
    my ($class, $files) = @_;

    my %files;
    foreach my $file (@{$files}) {
        if ($file =~ s/\.(.*$)//) {
            my $ext = $1;

            # add file $file to %file
            unless (defined $files{$file}) {
                $files{$file} = [$ext];
            } else {
                push(@{$files{$file}}, $ext);
            }
        } else {
            warn "[WARNING]  Unkown file type: $file\n";
        }
    }

    # collect different file types and add them to %all
    my %all;
    foreach my $file (keys %files) {
        my $ext = join(",", sort @{$files{$file}});
        $all{$file . "[" . $ext . "]"} = 1;
    }

    return sort(keys %all);
}

1;
