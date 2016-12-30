package CLGTextTools::SimMeasures::Cosine;

#twdoc
#
# Sim measure class which implements the cosine similarity.
#
# ---
# EM Oct 2015
# 
#/twdoc
#

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readTextFileLines arrayToHash/;

our @ISA=qw/CLGTextTools::SimMeasures::Measure/;


#twdoc new($class, $params)
#
# see parent. Additional parameters:
#
# * ``obsWeights``: ``obsWeights->{obs} = weight`` (e.g. IDF); if ``obsWeights->{obs}`` is undefined, a warning is sent and the weight is assumed to be zero.
#
#/twdoc
sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params, __PACKAGE__);
    $self->{obsWeights} = $params->{obsWeights};
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

    my ($obs, $freq1, $freq2);
    my $weights = $self->{obsWeights};
    my $sumProd = 0;
    my ($normSum1, $normSum2) = (0,0);
    while (($obs, $freq1) = each %$doc1) { # only common obs
        my $freq2 = $doc2->{$obs};
        $freq2 = 0 if (!defined($freq2)); 
	my $w = 1;
	if (defined($weights)) {
	    my $w = $weights->{$obs};
	    if (!defined($w)) {
		cluckLog($self->{logger}, "Undefined weight for obs '$obs', set to zero.");
		$w=0;
	    }
	}
	my ($v1, $v2)  = ( $freq1 * $w, $freq2 * $w);
	$normSum1 += $v1**2;
	$normSum2 += $v2**2;
	$sumProd += $v1 * $v2;
	$self->{logger}->trace("cosine loop 1: freq1=$freq1, freq2=$freq2, w=$w; v1=$v1, v2=$v2;  normSum1=$normSum1; normSum2=$normSum2; sumProd=$sumProd") if ($self->{logger});
    }
    while (($obs, $freq2) = each %$doc2) {
	if (!defined($doc1->{$obs})) {
	    my $w = 1;
	    if (defined($weights)) {
		my $w = $weights->{$obs};
		if (!defined($w)) {
		    cluckLog($self->{logger}, "Undefined weight for obs '$obs', set to zero.");
		    $w=0;
		}
	    }
	    $self->{logger}->trace("cosine loop 2: freq2=$freq2, w=$w; normSum2=$normSum2") if ($self->{logger});
	    $normSum2 += ($freq2 * $w)**2;
	}
    }
    my ($n1, $n2)  = ( sqrt($normSum1), sqrt($normSum2) );
    $self->{logger}->debug("compute cosine: norm1=$n1; norm2=$n2; sumProd=$sumProd") if ($self->{logger});
    return 0 if ($n1*$n2 == 0);
    return $sumProd / ($n1 * $n2);

}




1;
