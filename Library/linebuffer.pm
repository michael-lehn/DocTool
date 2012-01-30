package Linebuffer;
use strict;
use DocUtils;

sub new
{
    my $proto = shift;
    my %args = @_;

    my $class = ref($proto) || $proto;
    my $self  = {buffer => undef,
                 fromFile => undef,
                 docEnv => undef,
                 currentLineNumber => 0,
                 %args};
    bless ($self, $class);

    unless ($self->{docEnv}) {
        die "pass \"docEnv\"";
    }

    my $file = ($self->{fromFile}) ? $self->{fromFile}
                                   : $self->{docEnv}->{sourceFile};

    unless ($self->{buffer}) {
        $self->{buffer} = [ 
            DocUtils->LoadLinebuffer(file => $file,
                                     removeNewlines => 1,
                                     removeTrailingSpaces => undef) 
        ];
    }

    return $self;
}

sub end
{
    my $self = shift;
    my %args = (offset => 0,
                @_);

    return 1
        if $self->{currentLineNumber} + $args{offset} < 0;

    return undef
        if $self->{currentLineNumber} + $args{offset} <= $#{$self->{buffer}};

    return 1;
}

sub currentLineNumber
{
    my $self = shift;
    return $self->{currentLineNumber}+1;
}

sub moveLineCursor
{
    my $self = shift;
    my %args = (offset => 0,
                @_);
    $self->{currentLineNumber} += $args{offset};
}

sub line
{
    my $self = shift;
    my %args = (offset => 0,
                @_);

    return ${$self->{buffer}}[$self->{currentLineNumber} + $args{offset}];
}


1;