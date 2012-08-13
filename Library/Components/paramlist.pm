package ParamList;
use strict;
use String;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {items => undef,

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

    unless ($args{html}->{paramlist}) {
        $args{html}->{paramlist} = 1;
    }else {
        ++$args{html}->{paramlist};
    }

    $args{html}->addLine(line => "<table class=\"paramlist\">");

    for my $item (@{$self->{items}}) {
        $args{html}->addLine(line => "<tr class=\"paramlist\">");

        $args{html}->addLine(line => "<td class=\"paramlist_key\">");
        $item->{key}->html(html => $args{html});
        $args{html}->addLine(line => "</td>");

        $args{html}->addLine(line => "<td class=\"paramlist_value\">");
        $item->{value}->html(html => $args{html});
        $args{html}->addLine(line => "</td>");

        $args{html}->addLine(line => "</tr>\n");
    }

    $args{html}->addLine(line => "</table>");

    ++$args{html}->{paramlist};
    if ($args{html}->{paramlist}==0) {
        $args{html}->{paramlist} = undef;
    }
}

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    return undef
        unless $args{linebuffer}->line() =~ /^(\s*)(\S.*?)(\s{4,})[^\s+].*$/;

    my $l1 = length($1);
    my $l2 = $l1 + length($2) + length($3);

    my @items;
    while (! $args{linebuffer}->end()) {
        my $line = $args{linebuffer}->line();

        if ($line =~ /^\s{$l1,$l1}(\S.*)$/) {
#
#           Check if this is a new item.
#
            $line = $1;
            last if (length($line)<$l2-$l1+1);

            my $key   = substr($line, 0, $l2-$l1);
            my $value = substr($line, $l2-$l1);

            last unless $key =~ /^(.*\S)\s{4,}$/;
            $key = $1;

            $value =~ s/\s+\+$/ +/;

            push(@items, {key => $key, value => [$value]});
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }

        if ($line =~ /^(\s{$l2,}\S.*)$/) {
#
#           Belongs to last item
#
            my $value = substr($1, $l2);
            $value =~ s/\s+\+$/ +/;

            push(@{$items[-1]->{value}}, $value);
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }

        if ($line =~ /^\s*$/) {
#
#           Empty line (belongs to last item)
#
            push(@{$items[-1]->{value}}, "");
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        last;
    }

    my @adtItems;
    for my $item (@items) {
        my $linebuffer;

        $linebuffer = Linebuffer->new(buffer => [$item->{key}],
                                      docEnv => $args{linebuffer}->{docEnv});
        my $keyAdt = Parse->new(linebuffer => $linebuffer);

        $linebuffer = Linebuffer->new(buffer => $item->{value},
                                      docEnv => $args{linebuffer}->{docEnv});
        my $valueAdt = Parse->new(linebuffer => $linebuffer);

        push(@adtItems, {key => $keyAdt, value => $valueAdt});
    }
    my $paramList = ParamList->new(items => \@adtItems);
    return $paramList;
}

1;
