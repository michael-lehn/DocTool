package Function;
use strict;
use String;

sub Expand
{
    my $class = shift;
    my %args = (keyword => undef,
                optionString => undef,
                docEnv => undef,
                @_);

    if ($args{docEnv}->{functions}->{$args{keyword}}) {
        $args{keyword} = $args{docEnv}->{functions}->{$args{keyword}}->{body};
        if ($args{keyword} =~ s/\s*\((.*?)\)//) {
            my $newOptionString = $1;
            my @optionValues = split(",", $args{optionString});
            for (my $i=$#optionValues+1; $i>=1; --$i) {
                $newOptionString =~ s/\$$i/$optionValues[$i-1]/g;
            }
            $args{optionString} = $newOptionString;
        }
    }

    return ($args{keyword}, $args{optionString});
}

1;