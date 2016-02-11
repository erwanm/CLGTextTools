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
our @EXPORT_OK = qw/createDatasetsFromParams filterMinDocFreq generateDocFreqTable/;


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
    $self->{logger}->debug("Adding DocProvider; id=$docId") if ($self->{logger});
#    $self->{logger}->debug("Adding DocProvider; ref(doc)=".ref($doc)) if ($self->{logger});
    $self->{docs}->{$docId} = $doc;
#    print STDERR Dumper($self->{docs});
}


sub getMinDocFreq {
    my $self = shift;
    return $self->{minDocFreq};
}


sub getDocFreqTable {
    my $self = shift;
    return $self->{docFreqTable};
}


sub getDocsAsHash {
    my $self = shift;
    return $self->{docs};
}


sub getDocsAsList {
    my $self = shift;
    my @docs = values %{$self->{docs}};
#    print STDERR Dumper($self->{docs});
    map { die "bug undef doc!" if (!defined($_)); } values %{$self->{docs}};
    return \@docs;
}


#
# applyMinDocFreq($minDocFreq, $docFreqTable)
# 
# Removes all the observations which don't appear in at least $minDocFreq distinct documents according to $docFreqTable.
#
# * Caution: the observations are removed from the original DocProvider objects (and possibly underlying ObsCollection objects).
# * Must be called after all docs have been added to the collection.
# * If an observation doesn't exist in $docFreqTable, its doc frequency is assumed to be zero and the observation is therefore removed.
# * There is little sense using this method if the DocProvider objects have not been initialized with the same obs types list.
#
# Parameters:
# * $minDocFreq: the minimum doc frequency (nothing is done if the current min doc freq, default 1, is higher or equal than this parameter)
# * $docFreqTable: $docFreqTable->{obsType}->{obs} = doc freq ; if undef, uses the object doc freq table (if undef as well, computes the doc freq table based on the collection of documents itself)
#
sub applyMinDocFreq {
    my $self = shift;
    my $minDocFreq = shift;
    my $docFreqTable = shift;

    if (!defined($docFreqTable)) {
	$self->{logger}->debug("applyMinDocFreq: param doc freq table is undefined") if ($self->{logger});
	if (!defined($self->{docFreqTable})) {
	    $self->{logger}->debug("applyMinDocFreq: self->{docFreqTable} is undefined, computing it") if ($self->{logger});
	    my @docsObservs;
	    foreach my $docP (values %{$self->{docs}}) {
		push(@docsObservs, $docP->getObservations());
	    }
	    $self->{logger}->debug("applyMinDocFreq: ref(docsObservs[0])=".ref($docsObservs[0])) if ($self->{logger});
	    $self->{docFreqTable} = generateDocFreqTable(\@docsObservs, $self->{logger});
	    map { die "bug after!" if (!defined($_)); } values %{$self->{docs}};
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
		$res{$obsType}->{$obs} = $observs->{$obs};
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
    my $logger = shift;

    $logger->debug("Generating doc freq table from list of docs") if ($logger);
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


# static
#
# Returns a hash $docColl{datasetId} = DocCollection
#
# * docProviderParams as hash:  (see DocProvider)
# ** logging
# ** obsCollection params
# ** useCountFile
# * $datasetsIdsList = [ datasetId1, datasetId2, ..]
# * $mapIdToPath is either:
# ** a hash such that $mapIdToPath->{id} = <path>, where <path> points to a directory contaning the files to include in the dataset.
# ** a string <path>, which points to a directory where datasets directories named 'id' are expected, i.e. a dataset "x" is located in <path>/x/
# * $minDocFreq (optional): min doc frequency threshold; if >1, the collection is entirely populated (can take long) in order to generate the doc freq table. (currently can only be used with the collection itself as reference for doc freq)
# * $filePattern is optional: if specified, only files which satisfy the pattern are included in the dataset (the default value is "*.txt").
# * $logger (optional)
#
sub createDatasetsFromParams {
    my ($docProviderParams, $datasetsIdsList, $mapIdToPath, $minDocFreq, $filePattern, $logger) = @_;

    $logger->debug("Creating list of DocCollection objects from parameters") if ($logger);
    $filePattern= "*.txt" if (!defined($filePattern));
    $minDocFreq = 1 if (!defined($minDocFreq));
    my %docColls;
    foreach my $datasetId (@$datasetsIdsList) {
	my $path = (ref($mapIdToPath)) ? $mapIdToPath->{$datasetId}."/" : "$mapIdToPath/$datasetId/" ;
	$logger->debug("Creating DocCollection for id='$datasetId'; path='$path'") if ($logger);
	my $docColl = CLGTextTools::DocCollection->new({ logging => $docProviderParams->{logging} });
	foreach my $file (glob("$path/$filePattern")) {
	    $logger->trace("DocCollection '$datasetId'; adding file '$file'") if ($logger);
	    my %paramsThis = %$docProviderParams;
	    $paramsThis{filename} = $file;
	    my $doc = CLGTextTools::DocProvider->new(\%paramsThis);
	    $docColl->addDocProvider($doc);
	}
	$docColl->applyMinDocFreq($minDocFreq);
	$docColls{$datasetId} = $docColl;
    }
    return \%docColls;
}


1;
