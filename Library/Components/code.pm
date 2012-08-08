package Code;
use strict;
use String;
use Options;
use DocUtils;

sub Keyword
{
    return "CODE";
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
                 type => "cc",
                 linenumbers   => 0,
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
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    $self->convert(html => $args{html});
    for my $line (@{$self->{html}}) {
        $args{html}->addLine(line => $line, preserveIndent => 1);
    }
}

sub convert
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    my @codelines = Convert->CodeBlock(codelinesRef => $self->{lines},
                                       fileExtension => $self->{type},
                                       linenumbers => $self->{linenumbers});

    $args{html}->addLine(line => "<div class=\"code\">\n");
    if ($self->{options}->{file}) {
        $args{html}->addLine(line => "<div class=\"code_title\">\n");
        my $sourcePath = $args{html}->{docEnv}->{sourcePath};
        my $file = $self->{options}->{file};
 
        my $relPath = DocUtils->RelativePath(currentPath => $sourcePath,
                                      removeDestinationPrefix => $ENV{HTML_DIR},
                                      destinationPath => $ENV{DOWNLOAD_DIR});
        $relPath = $relPath . "/" . $file;
        $args{html}->addLine(line => "<a class=\"code\" href=\"$relPath\">");
        $args{html}->addLine(line => "$file\n");
        $args{html}->addLine(line => "</a>\n");
        $args{html}->addLine(line => "</div><!-- Blub -->\n");
    }
    $args{html}->addLine(linesRef => \@codelines);
    $args{html}->addLine(line => "</div><!-- code -->\n");
}

# sub convert
# {
#     my $self = shift;
#     my %args = (html => undef,
#                 @_);
# 
#     my $syntaxOnOff = "-c \"syntax on\" ";
#     # my $numbers = "-c \"set number\"";
#     my $numbers = "";
# 
#     my $fullpath = DocUtils->CreateFullpath(basename => "code",
#                                             extension => "cc",
#                                             prefix => $ENV{TMP_DIR});
# 
#     DocUtils->SaveLinebuffer(file => $fullpath,
#                              linesRef => $self->{lines},
#                              appendNewLine => 1);
# 
#     # generate html using vim
#     my $vim = $ENV{VIM};
#     my $convert = join(" ", "$vim -e -f",
#                              $syntaxOnOff, $numbers,
# #                            "-c \"let g:html_use_css=0\"",
#                              "-c \"runtime! syntax/2html.vim\"",
#                              "-c \"wq\" -c \"q\" $fullpath > /dev/null");
#     my $clean = "rm ${fullpath}.html";
#     system "$convert";
# 
#     my @linebuffer = DocUtils->LoadLinebuffer(file => "${fullpath}.html"); 
# 
# #    system "$clean";
# 
#     my @outBuffer;
#     while (my $line = shift(@linebuffer)) {
#         last if $line =~ /<body/;
#     }
#     push(@outBuffer, "<div class=\"code\">\n");
#     if ($self->{options}->{file}) {
#         push(@outBuffer, "<div class=\"code_title\">\n");
#         my $sourcePath = $args{html}->{docEnv}->{sourcePath};
#         my $file = $self->{options}->{file};
# 
#         my $relPath = DocUtils->RelativePath(currentPath => $sourcePath,
#                                              removeDestinationPrefix => $ENV{HTML_DIR},
#                                              destinationPath => $ENV{DOWNLOAD_DIR});
#         $relPath = $relPath . "/" . $file;
#         push(@outBuffer, "<a class=\"code\" href=\"$relPath\">$file</a>\n");
#         push(@outBuffer, "</div>\n");
#     }
#     push(@outBuffer, "<div class=\"code_content\"><font face=\"monospace\">\n");
#     my $lineNumber = 1;
#     while (my $line= shift(@linebuffer)) {
#         last if $line =~ /<\/body>/;
#         $line =~ s/ffff00/8B4513/g;
#         $line =~ s/00ff00/006400/g;
#         $line =~ s/ff6060/DC143C/g;
#         $line =~ s/8080ff/0000CD/g;
#         $line =~ s/‘/&lsquo;/g;
#         $line =~ s/’/&lsquo;/g;
# 
#         if ($numbers) {
#             chomp($line);
#             $line  = "<a name=\"line${lineNumber}\"></a>" . $line . "\n";
#         }
#         push(@outBuffer, $line);
#         ++$lineNumber
#     }
#     push(@outBuffer, "</font></div>\n");
#     push(@outBuffer, "</div>\n");
#     @{$self->{html}} = @outBuffer;
# }

1;
