package Comment;
use strict;

sub Parse
{
    my $class = shift;
    my %args = (linebuffer => undef,
                @_);

    die unless $args{linebuffer};

    my $found = undef;
    while (! $args{linebuffer}->end()) {
        last unless $args{linebuffer}->line() =~ /^\s*#/;
        $args{linebuffer}->moveLineCursor(offset => 1);
        $found = 1;
    }
    return $found;
}

1;