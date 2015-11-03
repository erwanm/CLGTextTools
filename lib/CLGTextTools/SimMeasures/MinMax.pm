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

our @ISA=qw/CLGTextTools::SimMeasures::Measure/;



sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params);
    return $self;
}



#
#
#
sub compute {
    my ($doc1, $doc2) = @_;

    my ($min, $max);
    my ($obs1, $freq1);
    while (($obs1, $freq1) = each %$doc1) {
        my $freq2 = $doc2->{$obs1};
        $freq2 = 0 if (!defined($freq2)); 
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
        $max += $freq2 if (!defined($doc1->{$obs2}));
    }

    return 0 if (!defined($min) || (!defined($max)) || ($max == 0));
    return $min / $max;
}
}

1;
