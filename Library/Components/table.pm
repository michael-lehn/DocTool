package Table;
use strict;
use Options;
use String;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {lines => undef,
                 optionString => undef,
                 docEnv => undef,

                 # character grid
                 grid => [],
                 gridRows => undef,
                 gridCols => undef,

                 # pos of grid points
                 colPos => [],
                 rowPos => [],

                 # actual table
                 numRows => undef,
                 numCols => undef,
                 rows => [],
                 rowSpans => [],
                 colSpans => [],

                 table_class => "default",
                 options => {},
                 @_};
    bless ($self, $class);

    die unless $self->{docEnv};

    my @options = Options->Split(string => $self->{optionString});

    if (scalar(@options)>0) {
        $self->{table_class} = shift(@options);
        shift(@options);
        %{$self->{options}} = @options;
    }


#TODO: move this part to Table->Parse(..)

    $self->{gridRows} = scalar @{$self->{lines}};
    $self->{gridCols} = length $self->{lines}->[0];

    my $j = index($self->{lines}->[0], "+");
    while ($j > -1) {
        push(@{$self->{colPos}}, $j);
        $j = index($self->{lines}->[0], "+", $j+1);
    }

    for (my $i=0; $i<$self->{gridRows}; ++$i) {
        unless ($self->{gridCols} == length $self->{lines}->[$i]) {
            print ">$self->{lines}->[0]<  length = $self->{gridCols}\n";
            print ">$self->{lines}->[$i]<  length = ",
                  length $self->{lines}->[$i], "\n";
            die;
        }
        push(@{$self->{grid}}, [ split(//, $self->{lines}->[$i]) ]);
        if ($self->{grid}->[$i][0] eq "+") {
            push(@{$self->{rowPos}}, $i);
        }
    }
    $self->{numRows} = scalar(@{$self->{rowPos}}) - 1;
    $self->{numCols} = scalar(@{$self->{colPos}}) - 1;

    for (my $i=0; $i<$self->{numRows}; ++$i) {
        my @spans = ((0) x $self->{numCols});
        push(@{$self->{rowSpans}}, [@spans]);
        push(@{$self->{colSpans}}, [@spans]);
    }

    for (my $j=0; $j<$self->{numCols}; ++$j) {
        for (my $i=0; $i<$self->{numRows}; ++$i) {
            my $extraSpan = $self->getExtraRowSpan($i, $j);
            $self->{rowSpans}->[$i][$j] = 1 + $extraSpan;
            $i += $extraSpan;
        }
    }

    for (my $i=0; $i<$self->{numRows}; ++$i) {
        for (my $j=0; $j<$self->{numCols}; ++$j) {
            my $extraSpan = $self->getExtraColSpan($i, $j);
            $self->{colSpans}->[$i][$j] = 1 + $extraSpan;
            $j += $extraSpan;
        }
    }

    for (my $i=0; $i<$self->{numRows}; ++$i) {
       my @colItems;
       for (my $j=0; $j<$self->{numCols}; ++$j) {
           my $rowSpan = $self->{rowSpans}->[$i][$j];
           my $colSpan = $self->{colSpans}->[$i][$j];
           my @lines = _cut($self->{grid},
                            $self->{rowPos}->[$i], $self->{colPos}->[$j],
                            $self->{rowPos}->[$i+$rowSpan],
                            $self->{colPos}->[$j+$colSpan]);
           my $linebuffer = Linebuffer->new(buffer => \@lines,
                                            docEnv => $self->{docEnv});
           my $adt = Parse->new(linebuffer => $linebuffer);
           push(@colItems, $adt);
       }
       push(@{$self->{rows}}, [@colItems]);
   }

   return $self;
}

sub getExtraRowSpan
{
    my ($self, $row, $col) = @_;

    my $seps = "-=";
    my $extraSpan = 0;
    for (my $i=$row+1; $i<$self->{numRows}; ++$i) {
        # check for row separator
        my $rowPos = $self->{rowPos}->[$i];
        my $from   = $self->{colPos}->[$col]+1;
        my $to     = $self->{colPos}->[$col+1]-1;

        my $incSpan = 0;
        for (my $jPos=$from; $jPos<=$to; ++$jPos) {
            unless ($self->{grid}->[$rowPos][$jPos] =~ /[$seps]/) {
                $incSpan = 1;
                last;
            }
        }
        if ($incSpan) {
            ++$extraSpan;
        } else {
            return $extraSpan;
        }
    }
    return $extraSpan;
}

sub getExtraColSpan
{
    my ($self, $row, $col) = @_;

    my $seps = "|";
    my $extraSpan = 0;
    for (my $j=$col+1; $j<$self->{numCols}; ++$j) {
        # check for col separator
        my $colPos = $self->{colPos}->[$j];
        my $from   = $self->{rowPos}->[$row]+1;
        my $to     = $self->{rowPos}->[$row+1]-1;

        my $incSpan = 0;
        for (my $iPos=$from; $iPos<=$to; ++$iPos) {
            unless ($self->{grid}->[$iPos][$colPos] =~ /[$seps]/) {
                $incSpan = 1;
                last;
            }
        }
        if ($incSpan) {
            ++$extraSpan;
        } else {
            return $extraSpan;
        }
    }
    return $extraSpan;
}

sub _cut
{
    my ($grid, $fromRow, $fromCol, $toRow, $toCol) = @_;

    my @lines;
    for (my $i=$fromRow+1; $i<$toRow; ++$i) {
        my $line = "";
        for (my $j=$fromCol+1; $j<$toCol; ++$j) {
            $line = $line . $grid->[$i][$j];
        }
        push(@lines, $line);
    }
    return @lines;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    my $css_class = "$self->{table_class} tabular";

    $args{html}->addLine(line => "<table class=\"$css_class\">");
    for (my $i=0; $i<$self->{numRows}; ++$i) {
        $args{html}->incrementIndentLevel();

        my $tr_css_class = "$css_class row";
        $args{html}->addLine(line => "<tr class=\"$tr_css_class\">");

        for (my $j=0; $j<$self->{numCols}; ++$j) {
            next if ($self->{rowSpans}->[$i][$j] == 0);
            next if ($self->{colSpans}->[$i][$j] == 0);

            my $item = $self->{rows}->[$i][$j];

            $args{html}->incrementIndentLevel();

            my $td_css_class = "$css_class row_$i col_$j";
            if ($i % 2 == 0) {
                $td_css_class = $td_css_class . " evenRow";
            } else {
                $td_css_class = $td_css_class . " oddRow";
            }
            if ($j % 2 == 0) {
                $td_css_class = $td_css_class . " evenCol";
            } else {
                $td_css_class = $td_css_class . " oddCol";
            }
            $td_css_class = "class=\"$td_css_class\"";

            my $opt = "";
            if ($self->{rowSpans}->[$i][$j]>1) {
                $opt = "rowspan=\"" . $self->{rowSpans}->[$i][$j] . "\"";
            } elsif ($self->{colSpans}->[$i][$j]>1) {
                $opt = "colspan=\"" . $self->{colSpans}->[$i][$j] . "\"";
            }

            $args{html}->addLine(line => "<td $td_css_class $opt>");
            $args{html}->incrementIndentLevel();

            $item->html(html => $args{html});

            $args{html}->decreaseIndentLevel();
            $args{html}->addLine(line => "</td>");
            $args{html}->decreaseIndentLevel();

        }
        $args{html}->addLine(line => "</tr>");
        $args{html}->decreaseIndentLevel();
    }

    $args{html}->addLine(line => "</table>");
}

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    my $char = "\\+";

    my $l = undef;
    my $option = undef;

    if ($args{linebuffer}->line() =~ /^(\s*)${char}.*$/) {
        $l = length($1);
    } elsif (! $args{linebuffer}->end(offset => 1)) {
        return undef
            unless $args{linebuffer}->line(offset => 1) =~ /^(\s*)${char}.*$/;
        $l = length($1);

        return undef
            unless $args{linebuffer}->line() =~ /\[([^]]*)\]/;
        $option = $1;
        $args{linebuffer}->moveLineCursor(offset => 1);
    } else {
        return undef;
    }

    my @lines;
    while (! $args{linebuffer}->end()) {
        if ($args{linebuffer}->line() =~ /^\s{$l,$l}(\S.*)\s*$/) {
            push(@lines, $1);
            $args{linebuffer}->moveLineCursor(offset => 1);
            next;
        }
        last;
    }

    return Table->new(lines => [ @lines ],
                      optionString => $option,
                      docEnv => $args{linebuffer}->{docEnv});
}

1;
