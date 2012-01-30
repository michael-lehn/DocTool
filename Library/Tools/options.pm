package Options;
use strict;

sub Split
{
    my $class = shift;
    my %args = (string => undef,
                @_);

    my @result;

    if ($args{string}) {
        my @options = split(",", $args{string});
        for (my $i=0; $i<=$#options; ++$i) {
            $options[$i] =~ s/^\s*//;
            $options[$i] =~ s/\s*$//;
        }

        for my $option (@options) {
            $option =~ /^(.*?)(=(.*))?$/;
            push(@result, $1);
            if (defined $3) {
                push(@result, $3);
            } else {
                push(@result, 1);
            }
        }
    }
    return @result;
}

1;
