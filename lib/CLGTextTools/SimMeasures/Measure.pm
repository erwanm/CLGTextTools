package CLGTextTools::SimMeasures::Measure;

# EM Oct 2015
# 
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readParamGroupAsHashFromConfig/;
use CLGTextTools::SimMeasures::Cosine;
use CLGTextTools::SimMeasures::MinMax;

use base 'Exporter';
our @EXPORT_OK = qw/createSimMeasureFromId/;



#
# $params:
# - logging
#
sub new {
    my ($class, $params, $subclass) = @_;
    my $self = {};
    $self->{logger} = Log::Log4perl->get_logger(defined($subclass)?$subclass:__PACKAGE__) if ($params->{logging});
    $self->{logger}->debug("Initializing '$subclass' object") if ($self->{logger});
 #	bless($self, $class);
    return $self; 	
}



#
# input: two hash refs, $doc->{ obs } = freq
#
sub compute {
    my ($self, $doc1, $doc2) = @_;
    confessLog($self->{logger}, "bug: calling an abstract method");
}


#
# static 'new' method which instantiates one of the non-abstract strategy classes.
# The class is specified by a string id, but if measureId is a ref then it is assumed
# to be an already initialized SimMeasure object; in this case $measureId is returned.
# TODO: explanations unclear?
#
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
