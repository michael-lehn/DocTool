package Link;
use strict;
use BerkeleyDB;
use MLDBM qw(BerkeleyDB::Btree);


BEGIN {
    die "[ERROR] Convert: \"DB_DIR\" not specified in configuration."
        unless defined $ENV{DB_DIR};

    DocUtils->Mkdir(path => $ENV{DB_DIR});


    #-- Links
    #
    #   KEY:    source code
    #   VALUE:  source code id
    #

    #our %DocId;
    tie our %DocId, "MLDBM",
        -Filename => "$ENV{DB_DIR}/Links_AddDocumentId.db",
        -Flags    => DB_CREATE
    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/Links_AddDocumentId.db\"";

#    tie our %ShortCuts, "MLDBM",
#        -Filename => "$ENV{DB_DIR}/Links_ShortCuts.db",
#        -Flags    => DB_CREATE
#    || die "[ERROR] can not tie to \"$ENV{DB_DIR}/Links_ShortCuts.db\"";

    our %ShortCuts;
    our %UnresolvedLinks
}

sub AddDocumentId
{
    my $class = shift;
    my %args =  (documentId => undef,
                 docEnv => undef,
                 @_);

    if (defined $Link::DocId{$args{documentId}}) {
        if ($Link::DocId{$args{documentId}}->{outputFile}
         ne $args{docEnv}->{outputFile}) {
            print STDERR "[ERROR] redefinition of link target ".
                         "\"$args{documentId}\":\n";
            print STDERR  "[ERROR]  ... old value =" .
                  " $Link::DocId{$args{documentId}}->{outputFile}\n";
            print STDERR  "[ERROR]  ... new value = ".
                          "$args{docEnv}->{outputFile}\n";
            die;
        }
    }
    $Link::DocId{$args{documentId}} = $args{docEnv};
}

sub LookUpDocumentId
{
    my $class = shift;
    my %args =  (documentId => undef,
                 @_);

    unless (defined $Link::DocId{$args{documentId}}) {
        die "[ERROR] No DocID \"$args{documentId}\" registered.";
    }
    return $Link::DocId{$args{documentId}};
}

sub DumpUnresolvedLinks
{
    my $class = shift;
    my %args =  (docEnv => undef,
                 @_);

    my @keys = keys %Link::UnresolvedLinks;
    for my $unresolved (@keys) {
        print "[ERROR] Unresolved link $unresolved\n";
    }
    if (scalar(@keys)>0) {
        return 0;
    }
    return 1;
}

sub AddUnresolvedLink
{
    my $class = shift;
    my %args = (key        => undef,
                linkObject => undef,
                @_);

    die unless defined $args{key};

    unless (defined $Link::UnresolvedLinks{$args{key}}) {
        $Link::UnresolvedLinks{$args{key}} = [];
    }
    push(@{$Link::UnresolvedLinks{$args{key}}}, $args{linkObject});
}

sub ResolveLink
{
    my $class = shift;
    my %args = (key          => undef,
                destination  => undef,
                mark         => undef,
                @_);

    die unless defined $args{key};

    my $found = 0;
    foreach my $unresolved (keys %Link::UnresolvedLinks) {
        if ($unresolved =~ /^$args{key}$/) {
            $found = 1;

            foreach my $linkObject (@{$Link::UnresolvedLinks{$unresolved}}) {

                $linkObject->{dest} = $unresolved;
                $linkObject->{mark} = $args{mark};
                my $replace = '"' . $args{destination} . '"';

                $linkObject->{dest} =~ s/^$args{key}$/$replace/ee;
            }

            delete $Link::UnresolvedLinks{$unresolved};
        }
    }


    unless ($found) {
        die "[ERROR] Can not resolve unused link-pattern \"$args{key}\"";
    } else {
#        print "resolve $args{key}\n";
    }
}



sub SingleQuotes
{
    return undef;
}

sub DoubleQuotes
{
    return "_";
}

################################################################################

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {string => undef,

                 shortcut => undef,
                 contains => undef,
                 css_class => undef,

                 #needs to be resolved:
                 dest => undef,
                 mark => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{string};

    $self->{shortcut} = $self->{string}->{value};
    $self->{string}->{value} =~ s/\[[^\]]+\]$//;
    $self->{contains} = String->Parse(string => $self->{string});

    Link->AddUnresolvedLink(key => $self->{shortcut},
                            linkObject => $self);

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    unless ($self->{dest}) {
        die "[ERROR] Unresolved local",
            " shortcut \"$self->{string}->{value}\"\n";
    }
    my $html = Html->MakeLink(fromDocEnv => $args{html}->{docEnv},
                              toDocEnv => $self->{dest},
                              mark => $self->{mark});

    my $openTag = "<a href=\"$html\">";
    my $closeTag = "</a>";

    $args{html}->append(line => "$openTag");
    for my $component (@{$self->{contains}}) {
        $component->html(html => $args{html});
    }
    $args{html}->append(line => "$closeTag");
}

sub plain
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    my $plain = "";
    for my $component (@{$self->{contains}}) {
        $plain = $plain . $component->plain();
    }

    return $plain;
}

1;
