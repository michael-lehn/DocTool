package Parse;
use strict;

use Block;
use BlockBox;
use Comment;
use Defs;
use List;
use Paragraph;
use Section;
use String;
use Table;
use Title;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {linebuffer => undef,

                 contains => [],
                 @_};
    bless ($self, $class);
    $self->run();
    return $self;
}

# Expects one of these components
#  - title
#  - section
#  - block, e.g.
#      - list
#      - table
#      - other types of blocks
#  - attribute definitions
#  - paragraph

sub run
{
    my $self = shift;

    my @Components = (qw(Comment),
                      qw(Title),
                      qw(Section),
                      qw(List),
                      qw(Table),
                      qw(Block),
                      qw(BlockBox),
                      qw(Defs),
                      qw(Paragraph));

    while (! $self->{linebuffer}->end()) {
        my $found = undef;
        for my $component (@Components) {
            $found = $component->Parse(linebuffer => $self->{linebuffer});
            if ($found) {
                unless ($found == 1) {
                    push (@{$self->{contains}}, $found);
                }
                last;
            }
        }
        next if $found;

        # check for empty lines
        die unless $self->emptyLine();
    }
}

sub emptyLine
{
    my $self = shift;

    return undef if $self->{linebuffer}->line() =~ /\S/;

    $self->{linebuffer}->moveLineCursor(offset => 1);
    return 1;
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    for my $component (@{$self->{contains}}) {
        $component->html(html => $args{html});
    }
}

1;
