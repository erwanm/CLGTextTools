package CLGTextTools::SimMeasures::MinMax;

# EM Oct 2015
# 
#
#

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readTextFileLines arrayToHash/;
use CLGTextTools::SimMeasures::Measure;

our @ISA=qw/CLGTextTools::SimMeasures::Measure/;



sub new {
    my ($class, $params) = @_;
     my $self = $class->SUPER::new($params, __PACKAGE__);
    bless($self, $class);
    return $self;
}



#
#
#
sub compute {
    my ($self, $doc1, $doc2) = @_;

    $self->{logger}->debug("compute similarity") if ($self->{logger});
    my ($min, $max);
    my ($obs1, $freq1);
    while (($obs1, $freq1) = each %$doc1) {
        my $freq2 = $doc2->{$obs1};
        $freq2 = 0 if (!defined($freq2)); 
	$self->{logger}->trace("  obs = '$obs1'; freq1 = $freq1; freq2 = $freq2") if ($self->{logger});
        if ($freq1 <= $freq2) {
	    $min += $freq1 ;
	    $max += $freq2;
        } else {
	    $min += $freq2 ;
	    $max += $freq1;
        }
    }
    my ($obs2, $freq2);  
    while (($obs2, $freq2) = each %$doc2) {
	$self->{logger}->trace("  obs = '$obs2'; freq1 = 0; freq2 = $freq2") if ($self->{logger});
        $max += $freq2 if (!defined($doc1->{$obs2}));
    }

    return 0 if (!defined($min) || (!defined($max)) || ($max == 0));
    return $min / $max;
}

1;
