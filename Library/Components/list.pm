package List;
use strict;
use String;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {items => undef,

                 ordered => undef,
                 arabic => undef,
                 lowerCaseAlpha => undef,
                 upperCaseAlpha => undef,
                 lowerCaseRoman => undef,
                 upperCaseRoman => undef,

                 css_class => undef,
                 @_};
    bless ($self, $class);

    return $self;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    my $openTag;
    my $closeTag;
    my $class;

    unless ($self->{ordered}) {
        $openTag = "ul";
        $closeTag = "</ul>";
        $class = "itemize";
    } else {
        $openTag = "ol";
        $closeTag = "</ol>";
        $class = "enumerate";
    }

    $args{html}->addLine(line => "<$openTag class=\"$class\">");
    $args{html}->incrementIndentLevel();
    for my $item (@{$self->{items}}) {
        $args{html}->addLine(line => "<li>");
        $args{html}->incrementIndentLevel();

        $item->html(html => $args{html});

        $args{html}->decreaseIndentLevel();
        $args{html}->addLine(line => "</li>");
    }
    $args{html}->decreaseIndentLevel();

    $args{html}->addLine(line => "$closeTag");
}

sub ParseUnordered
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    my $chars = "[-+*]";
    return undef unless $args{linebuffer}->line() =~ /^(\s*)($chars)(\s+)\S.*$/;

    my $l = length($1);
    my $char = "[$2]";
    my $dl = length($3);
    my $L = $l + 1 + $dl;

    my @items;
    while (! $args{linebuffer}->end()) {
        if ($args{linebuffer}->line() =~ /^\s{$l,$l}$char\s{$dl,$dl}(\S.*)$/) {
            push(@items, [$1]);
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        if ($args{linebuffer}->line() =~ /^(\s{$L,}\S.*)$/) {
            push(@{$items[-1]}, substr($1, $L));
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        if ($args{linebuffer}->line() =~ /^\s*$/) {
            push(@{$items[-1]}, "");
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        last;
    }

    my @adtItems;
    for my $item (@items) {
        my $linebuffer = Linebuffer->new(buffer => $item,
                                         docEnv => $args{linebuffer}->{docEnv});
        my $adt = Parse->new(linebuffer => $linebuffer);

        push(@adtItems, $adt);
    }
    return List->new(items => [ @adtItems ]);
}

sub ParseOrdered
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    my $chars = "[\\d]";
    return undef unless $args{linebuffer}->line()
                        =~ /^(\s*)($chars)($chars*\.\s+)\S.*$/;

    my $l = length($1);
    my $char = "[\\d]";
    my $dl = length($3);
    my $L = $l + 1 + $dl;

    my @items;
    while (! $args{linebuffer}->end()) {
        if ($args{linebuffer}->line() =~ /^\s{$l,$l}$char+\.\s{1,$dl}(\S.*)$/) {
            push(@items, [$1]);
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        if ($args{linebuffer}->line() =~ /^(\s{$L,}\S.*)$/) {
            push(@{$items[-1]}, substr($1, $L));
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        if ($args{linebuffer}->line() =~ /^\s*$/) {
            push(@{$items[-1]}, "");
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        last;
    }

    my @adtItems;
    for my $item (@items) {
        my $linebuffer = Linebuffer->new(buffer => $item,
                                         docEnv => $args{linebuffer}->{docEnv});
        my $adt = Parse->new(linebuffer => $linebuffer);

        push(@adtItems, $adt);
    }
    return List->new(items => [ @adtItems ], ordered => 1);
}

sub Parse
{
    my $class = shift;
    my %args = (@_);

    if (my $result = $class->ParseUnordered(%args)) {
        return $result;
    }
    if (my $result = $class->ParseOrdered(%args)) {
        return $result;
    }
    return undef;
}

1;
