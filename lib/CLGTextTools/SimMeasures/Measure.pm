package CLGTextTools::SimMeasures::Measure;


#twdoc
#
# Parent class for similarity measures between documents, where documents are "bags of observations" 
#
# ---
# EM Oct 2015
# 
#/twdoc


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readParamGroupAsHashFromConfig/;
use CLGTextTools::Stats qw/normalizeFreqDoc/;
use  CLGTextTools::DocProvider;

use CLGTextTools::SimMeasures::Cosine;
use CLGTextTools::SimMeasures::MinMax;

use base 'Exporter';
our @EXPORT_OK = qw/createSimMeasureFromId/;


#twdoc new($class, $params, $subclass)
#
#
#
# ``$params``:
#
# * logging
#
#/twdoc
sub new {
    my ($class, $params, $subclass) = @_;
    my $self = {};
    $self->{logger} = Log::Log4perl->get_logger(defined($subclass)?$subclass:__PACKAGE__) if ($params->{logging});
    $self->{logger}->debug("Initializing '$subclass' object") if ($self->{logger});
 #	bless($self, $class);
    return $self; 	
}


#twdoc compute($self, $doc1, $doc2)
#
# * ''abstract''
#
# returns the similarity score between the two documents.
#
# * input: two hash refs, ``$doc->{ obs } = freq``
#
#/twdoc
sub compute {
    my ($self, $doc1, $doc2) = @_;
    confessLog($self->{logger}, "bug: calling an abstract method");
}



#
#twdoc normalizeCompute($self, $doc1, $doc2, $obsTypeOrsize1, $size2)
#
# returns the similarity score between the two documents after normalization (by computing relative frequencies).  Can be used in two distinct ways, determined by the number of arguments:
#
# * 4 arguments: ``$docX`` is a hash of the form: ``$docX->{ obs } = freq``; ``$obsTypeOrsize1`` and ``$size2`` are the total number of observations in each doc.
# * 3 arguments: ``$docX`` is a ``DocProvider`` and ``$obsTypeOrsize1`` is the obs type used for computing the similarity. The relevant sizes are read from the ``DocProvider`` objects.
#
#/twdoc
sub normalizeCompute {
    my ($self, $doc1, $doc2, $obsTypeOrsize1, $size2) = @_;

    my ($normalizedDoc1, $normalizedDoc2);
    if (defined($size2)) {
	$normalizedDoc1 = normalizeFreqDoc($doc1, $obsTypeOrsize1, $self->{logger});
	$normalizedDoc2 = normalizeFreqDoc($doc2, $size2, $self->{logger});
    } else { # DocProvider objects and obs type
	$normalizedDoc1 = normalizeFreqDoc($doc1->getObservations($obsTypeOrsize1), $doc1->getNbObsTotal($obsTypeOrsize1), $self->{logger});
	$normalizedDoc2 = normalizeFreqDoc($doc2->getObservations($obsTypeOrsize1), $doc2->getNbObsTotal($obsTypeOrsize1), $self->{logger});
    }
    $self->compute($normalizedDoc1, $normalizedDoc2);
}



#twdoc createSimMeasureFromId($measureId, $params, ?$removeMeasureIdPrefix)
#
# static 'new' method which instantiates one of the non-abstract measure classes.
# The class is specified by a string id, but if ``$measureId`` is a ref then it is assumed
# to be an already initialized ``SimMeasure`` object; in this case the object ``$measureId`` is simply returned.
# The parameters for the measure are read from ``$params``.
#
# * ``$removeMeasureIdPrefix``: if specified, then only the parameters which start with this prefix are transmitted, after removing the prefix.
#
#/twdoc
sub createSimMeasureFromId {
    my $measureId = shift;
    my $params = shift;
    my $removeMeasureIdPrefix = shift; # optional

    my $res;
    my $myParams;
    if (defined($measureId) && ref($measureId)) { # if not a scalar (i.e. normally a reference to a an object)
	return $measureId;
    } else {
	if ($removeMeasureIdPrefix) {
	    $myParams = readParamGroupAsHashFromConfig($params, $measureId);
	    $myParams->{logging} = $params->{logging}; # add general parameters; TODO: others?
	} else {
	    $myParams = $params;
	}
	if ($measureId eq "minmax") {
	    $res = CLGTextTools::SimMeasures::MinMax->new($myParams);
	} elsif ($measureId eq "cosine") {
	    $res = CLGTextTools::SimMeasures::Cosine->new($myParams);
	} else {
	    confess("Error: invalid measure id '$measureId', cannot instanciate Measure class.");
	}
	return $res;
    }
}



1;
