package CLGTextTools::DocCollection;

# EM Oct 2015
# 
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog/;
use CLGTextTools::Commons qw//;
use CLGTextTools::DocProvider;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw//;


#
# Provides methods to process a set of documents (represented as DocProvider objects) together.
#
# Most methods have a static version (thus can be used without instantiating an object).
#


#
#
# $params:
# * logging
#
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	$self->{docs} = {};
	$self->{docFreqTable} = undef;
	$self->{minDocFreq} = 1;
 	bless($self, $class);
	return $self; 	
}



sub addDocProvider {
    my $self = shift;
    my $doc = shift;

    my $docId = $doc->getFilename();
    $self->{docs}->{docId} = $doc;
}


sub getMinDocFreq {
    my $self = shift;
    return $self->{minDocFreq};
}


sub getDocFreqTable {
    my $self = shift;
    return $self->{docFreqTable};
}


#
# applyMinDocFreq($minDocFreq, $docFreqTable, $deleteInOriginalDoc)
# 
# Removes all the observations which don't appear in at least $minDocFreq distinct documents according to $docFreqTable.
#
# * Caution: the observations are removed from the original DocProvider objects (and possibly underlying ObsCollection objects).
# * Must be called after all docs have been added to the collection.
# * If an observation doesn't exist in $docFreqTable, its doc frequency is assumed to be zero and the observation is therefore removed.
# * There is little sense using this method if the DocProvider objects have not been initialized with the same obs types list.
#
# Parameters:
# * $minDocFreq: the minimum doc frequency (nothing is done if the current min doc freq, default 1, is lower or equal than this parameter)
# * $docFreqTable: $docFreqTable->{obsType}->{obs} = doc freq ; if undef, uses the object doc freq table (if undef as well, computes the doc freq table based on the collection of documents)
#
sub applyMinDocFreq {
    my $self = shift;
    my $minDocFreq = shift;
    my $docFreqTable = shift;

    if (!defined($docFreqTable)) {
	if (!defined($self->{docFreqTable})) {
	    my @docs = values %{$self->{docs}};
	    $self->{docFreqTable} = generateDocFreqTable(\@docs);
	}
	$docFreqTable = $self->{docFreqTable};
    } 
    my %res;
    if ($minDocFreq > $self->{minDocFreq}) {
	foreach my $docKey (keys %{$self->{docs}}) {
	    my $allObservsDoc = $self->{docs}->{$docKey}->getObservations();
	    filterMinDocFreq($allObservsDoc, $minDocFreq, $docFreqTable, 1);
	}
	$self->{minDocFreq} = $minDocFreq;
    }
}



# filterMinDocFreq($inputDoc, $minDocFreq, $minFreqTable, $deleteInOriginalDoc)
#
# * ''static''
#
# returns a hash by obs type corresponding to $inputDoc but in which observations which don't appear in at least $minDocFreq distinct documents (according to $docFreqTable) have been removed.
#
# * If an observation doesn't exist in $docFreqTable, its doc frequency is assumed to be zero and the observation is therefore removed.
#
# Parameters:
# * $inputDoc: $inputDoc->{obstype}->{obs} = freq
# * $minDocFreq: the minimum doc frequency
# * $docFreqTable: $docFreqTable->{obsType}->{obs} = doc freq
# * $deleteInOriginalDoc: optional; if defined and true, then the input hash is modified (observations are therefore removed permanently from the underlying object). By default a new hash is created containing only the observations which satisfy the condition.
# * output: $outputDoc->{obstype}->{obs} = freq 
#
#
sub filterMinDocFreq {
    my ($inputDoc, $minDocFreq, $docFreqTable, $deleteInOriginalDoc) = @_;

    my %res;
    my ($obsType, $observs);
    while (($obsType, $observs) = each %$inputDoc) {
	foreach my $obs (keys %$observs) {
	    my $docFreq = $docFreqTable->{$obsType}->{$obs};
	    $docFreq = 0 if (!defined($docFreq));
	    if ($deleteInOriginalDoc) {
		delete $observs->{$obs} if ($docFreq < $minDocFreq);
	    } else {
		$res->{$obsType}->{$obs} = $observs->{$obs};
	    }
	}
    }
    return ($deleteInOriginalDoc) ? $inputDoc : \%res;
    
}



# generateDocFreqTable($documents)
#
# * ''static''
#
# Returns a hash by obs type which gives for each observation <obs> the number of documents which contain at least one occurrence of <obs>.
#
# * documents: $documents->[docNo]->{obsType}->{obs} = freq
# * output: $docFreqTable->{obsType}->{obs} = doc freq
#
# * There is little sense using this method if the documents have not been initialized with the same obs types list.
#
#
sub generateDocFreqTable {
    my $documents = shift;

    my %res;
    foreach my $doc (@$documents) {
	my ($obsType, $observs);
	while (($obsType, $observs) = each %$doc) {
	    foreach my $obs (keys %$observs) {
		$res{$obsType}->{$obs}++;
	    }
	}
    }
    return \%res;
    
}


1;
