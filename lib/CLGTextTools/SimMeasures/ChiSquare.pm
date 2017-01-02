package CLGTextTools::SimMeasures::ChiSquare;

#twdoc
#
# Sim measure class which implements the chi-square distance, turned into a similarity be taking the opposite of the result (''NEGATIVE'' value).
#
# ---
# EM Dec 2016
# 
#/twdoc
#

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::SimMeasures::Measure;

our @ISA=qw/CLGTextTools::SimMeasures::Measure/;


#twdoc new($class, $params)
#
# see parent, no additional parameter.
#
#/twdoc
sub new {
    my ($class, $params) = @_;
     my $self = $class->SUPER::new($params, __PACKAGE__);
    bless($self, $class);
    return $self;
}



#twdoc compute($self, $doc1, $doc2)
#
# see parent.
#
#/twdoc
sub compute {
    my ($self, $doc1, $doc2) = @_;

    $self->{logger}->debug("compute chi square distance") if ($self->{logger});


    my ($obs1, $freq1);
    my $sum = 0;
    while (($obs1, $freq1) = each %$doc1) {
        my $freq2 = $doc2->{$obs1};
        $freq2 = 0 if (!defined($freq2)); 
	$self->{logger}->trace("  obs = '$obs1'; freq1 = $freq1; freq2 = $freq2") if ($self->{logger});
	my $sqDiff = ($freq1 - $freq2)**2;
	if ($freq1 + $freq2 != 0) { # normally shouldn't happen but who knows
	    $sum += $sqDiff / ($freq1 + $freq2);
	}
    }
    my ($obs2, $freq2);  
    while (($obs2, $freq2) = each %$doc2) {
	if (!defined($doc1->{$obs2})) {
	    $self->{logger}->trace("  obs = '$obs2'; freq1 = 0; freq2 = $freq2") if ($self->{logger});
	    $sum += $freq2**2 / $freq2 if ($freq2 != 0);
	}
    }

    $self->{logger}->debug("final similarity score: ".(-$sum)) if ($self->{logger});

    return -$sum; 
}

1;
