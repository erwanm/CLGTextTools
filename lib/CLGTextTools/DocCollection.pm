package CLGTextTools::DocCollection;

#twdoc
#
# This class provides methods to process a set of documents (represented as ``DocProvider`` objects) together. Additional computations can be processed on the collection of documents, in particular about the document frequency (i.e. number of documents which contain a given observation) and global frequency (frequency in all documents).
#
# * Most methods have a static version (thus can be used without instantiating an object).
#
#
# ---
# EM Oct 2015
# 
#/twdoc


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog warnLog/;
use CLGTextTools::Commons qw/readTextFileLines/;
use CLGTextTools::DocProvider;
use File::Basename;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw/createDatasetsFromParams filterMinDocFreq generateDocFreqTable/;

our $filePrefixGlobalCount = "global";
our $filePrefixDocFreqCount = "doc-freq";




#twdoc new($class, $params)
#
# * logging
# * globalPath: optional; if specified, specifies the directory where the global count files and the doc freq count files are read from/written to. If undefined, the global/doc freq data is never read or written from files (i.e. always computed, if required).
#
#/twdoc
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	$self->{globalPath} =  $params->{globalPath};
	$self->{docs} = {};
	$self->{docFreqTable} = undef;
	$self->{minDocFreq} = 0;
	$self->{globalCountDocProv} = undef;
	$self->{docFreqCountDocProv} = undef;
 	bless($self, $class);
	return $self; 	
}



#twdoc addDocProvider($self, $doc)
#
# adds a document to the collection.
#
#/twdoc
sub addDocProvider {
    my $self = shift;
    my $doc = shift;

    my $docId = $doc->getFilename();
    $self->{logger}->debug("Adding DocProvider; id=$docId") if ($self->{logger});
#    $self->{logger}->debug("Adding DocProvider; ref(doc)=".ref($doc)) if ($self->{logger});
    $self->{docs}->{$docId} = $doc;
#    print STDERR Dumper($self->{docs});
}


#twdoc getMinDocFreq($self)
#
# returns the current min doc frequency for the collection.
#
#/twdoc
sub getMinDocFreq {
    my $self = shift;
    return $self->{minDocFreq};
}


#twdoc getDocFreqTable($self)
#
# returns the document frequency table of the collection: ``$res->{obsType}->{obs} = doc freq``. The doc frequencies are computed if the table wasn't defined already.
#
#/twdoc
sub getDocFreqTable {
    my $self = shift;

    if (!defined($self->{docFreqCountDocProv})) {
	$self->{logger}->debug("getDocFreqTable: self->{docFreqTable} is undefined, obtaining it") if ($self->{logger});
	$self->{docFreqCountDocProv} = $self->getDocFreqCountDocProv();
    }
    return $self->{docFreqCountDocProv}->getObservations();
}



#twdoc getDocsAsHash($self)
#
# returns the hash of docs in the collection (keys are the filenames).
#
#/twdoc
sub getDocsAsHash {
    my $self = shift;
    return $self->{docs};
}


#twdoc getDocsAsList($self)
#
# returns a list containing the ``DocProvider`` objects in the collection.
#
#/twdoc
sub getDocsAsList {
    my $self = shift;
    my @docs = values %{$self->{docs}};
#    print STDERR Dumper($self->{docs});
    map { die "bug undef doc!" if (!defined($_)); } values %{$self->{docs}};
    return \@docs;
}


#twdoc getNbDocs($self)
#
# returns the number of ``DocProvider`` objects in the collection.
#
#/twdoc
sub getNbDocs {
    my $self = shift;
    return scalar(keys %{$self->{docs}});
}



#twdoc applyMinDocFreq($self, $minDocFreq, $docFreqTable)
# 
# Removes all the observations which don't appear in at least ``$minDocFreq`` distinct documents according to $docFreqTable.
#
# * Caution: the observations are removed from the original ``DocProvider`` objects (and possibly underlying ObsCollection objects).
# * Must be called after all docs have been added to the collection.
# * If an observation doesn't exist in ``$docFreqTable``, its doc frequency is assumed to be zero and the observation is therefore removed.
# * There is little sense using this method if the DocProvider objects have not been initialized with the same obs types list.
#
# Parameters:
# * ``$minDocFreq``: the minimum doc frequency (nothing is done if the current min doc freq, default 0, is higher or equal to this parameter)
# * ``$docFreqTable``: ``$docFreqTable->{obsType}->{obs} = doc freq`` ; if undef, uses the object doc freq table (if undef as well, computes the doc freq table based on the collection of documents itself)
#
#/twdoc
sub applyMinDocFreq {
    my $self = shift;
    my $minDocFreq = shift;
    my $docFreqTable = shift;

    my %res;
    if ($minDocFreq > $self->{minDocFreq}) {
	if (!defined($docFreqTable)) {
	    $self->{logger}->debug("applyMinDocFreq: param doc freq table is undefined") if ($self->{logger});
	    $docFreqTable = $self->getDocFreqTable();
	} 
	foreach my $docKey (keys %{$self->{docs}}) {
	    my $allObservsDoc = $self->{docs}->{$docKey}->getObservations();
	    filterMinDocFreq($allObservsDoc, $minDocFreq, $docFreqTable, 1);
	}
	$self->{minDocFreq} = $minDocFreq;
    }
}



#twdoc filterMinDocFreq($inputDoc, $minDocFreq, $minFreqTable, $deleteInOriginalDoc)
#
# * ''static''
#
# Returns a hash by obs type corresponding to ``$inputDoc`` but in which observations which don't appear in at least ``$minDocFreq`` distinct documents (according to ``$docFreqTable``) have been removed.
#
# * If an observation doesn't exist in ``$docFreqTable``, its doc frequency is assumed to be zero and the observation is therefore removed.
#
# Parameters:
# * ``$inputDoc``: ``$inputDoc->{obstype}->{obs} = freq``
# * ``$minDocFreq``: the minimum doc frequency
# * ``$docFreqTable``: ``$docFreqTable->{obsType}->{obs} = doc freq``
# * ``$deleteInOriginalDoc``: optional; if defined and true, then the input hash is modified (observations are therefore removed permanently from the underlying object). By default a new hash is created containing only the observations which satisfy the condition.
# * output: ``$outputDoc->{obstype}->{obs} = freq``
#
#/twdoc
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



#twdoc generateDocFreqTable($documents)
#
# * ''static''
#
# Returns a hash by obs type which gives for each observation ``obs`` the number of documents which contain at least one occurrence of ``obs``.
#
# * ``$documents``: ``$documents->[docNo]->{obsType}->{obs} = freq``
# * output: ``$docFreqTable->{obsType}->{obs} = doc freq``
#
# * There is little sense using this method if the documents have not been initialized with the same obs types list.
#
#/twdoc
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



#twdoc createDatasetsFromParams($docProviderParams, $datasetsIdsList, $mapIdToPath, ?$minDocFreq, ?$filePattern, ?$logger, ?$removePrefix)
#
# * ''static''
#
# Generates a set of ``DocCollection`` objects based on the parameters passed as argument.
#
#
# * ``$docProviderParams`` as hash:  (see ``DocProvider``)
# ** logging
# ** obsCollection params
# ** useCountFile
# * ``$datasetsIdsList = [ datasetId1, datasetId2, ..]``
# * ``$mapIdToPath`` is either:
# ** a hash such that ``$mapIdToPath->{id} = path``, where ``path`` points to a directory contaning the files to include in the dataset; alternatively, if path points to a file, this file contains the list of all documents to include (one by line).
# ** a string ``path``, which points to a directory where datasets directories named 'id' are expected, i.e. a dataset ``x`` is located in ``path/x/``
# * ``$minDocFreq`` (optional): min doc frequency threshold; if >0, the collection is entirely populated (can take long) in order to generate the doc freq table. (currently can only be used with the collection itself as reference for doc freq). Interpreted as relative freq (wrt number of docs) if the value is lower than 1.
# * ``$filePattern`` is optional: if specified, only files which satisfy the pattern are included in the dataset (the default value is ``*.txt``).
# * ``$logger`` (optional)
# * ``$removePrefix``: optional, path prefix to remove from the doc id. If using special value "BASENAME", then the file basename is used.
# * ''Returns'' a hash ``$docColl{datasetId} = DocCollection``
#
#/twdoc
sub createDatasetsFromParams {
    my ($docProviderParams, $datasetsIdsList, $mapIdToPath, $minDocFreq, $filePattern, $logger, $removePrefix) = @_;

    $logger->debug("Creating list of DocCollection objects from parameters") if ($logger);
    warnLog($logger, "Warning: no dataset provided (empty list)!") if (scalar(@$datasetsIdsList) == 0);
    $filePattern= "*.txt" if (!defined($filePattern));
    $minDocFreq = 0 if (!defined($minDocFreq));
    my %docColls;
    foreach my $datasetId (@$datasetsIdsList) {
	my $path = (ref($mapIdToPath)) ? $mapIdToPath->{$datasetId} : "$mapIdToPath/$datasetId/" ;
	$path =~ s:/+:/:g; 
	my $docFiles;
	if (-f $path) {
	    $docFiles = readTextFileLines($path, 1, $logger);
	    $logger->debug("Creating DocCollection for id='$datasetId'; list of files read from '$path'") if ($logger);
	    $path = dirname($path);
	} else {
	    @$docFiles = glob("$path/$filePattern");
	    $logger->debug("Creating DocCollection for id='$datasetId'; path='$path', pattern='$path/$filePattern'") if ($logger);
	}
	my $docColl = CLGTextTools::DocCollection->new({ logging => $docProviderParams->{logging}, "globalPath" => $path });
	foreach my $file (@$docFiles) {
	    my $docId = $file;
	    if (defined($removePrefix)) {
		if ($removePrefix eq "BASENAME") {
		    $docId = basename($file);
		} else {
		    $docId =~ s/^\Q$removePrefix//g ;
		}
	    }
	    $logger->debug("DocCollection '$datasetId'; adding file '$file' with id = '$docId'") if ($logger);
	    my %paramsThis = %$docProviderParams;
	    $paramsThis{filename} = $file;
	    $paramsThis{id} = $docId;
	    my $doc = CLGTextTools::DocProvider->new(\%paramsThis);
	    $docColl->addDocProvider($doc);
	}
	my $nbDocs = scalar(keys %{$docColl->{docs}});
	warnLog($logger, "Warning: dataset '$datasetId' is empty!") if ($nbDocs == 0);
	$minDocFreq *= $nbDocs if ($minDocFreq < 1); # if min doc freq < 1, interpret as relative frequency wrt to number of docs in the collection
	$docColl->applyMinDocFreq($minDocFreq);
	$docColls{$datasetId} = $docColl;
    }
    return \%docColls;
}



#twdoc populateAll($self)
#
# Useful only if writeCountFiles is true: forces parsing every document and writing count files. 
#
# * remark: global counts and doc freq are not processed.
#
#/twdoc
sub populateAll {
    my $self = shift;

    my $documents = $self->{docs};
    my $nbDocs= scalar(keys %$documents);
    $self->{logger}->debug("Populating all $nbDocs documents in the collection") if ($self->{logger});
    my %res;
    foreach my $doc (keys %$documents) {
	$documents->{$doc}->populate();
    }
}




#twdoc getGlobalCountDocProv($self)
#
# returns a ``DocProvider`` object contaning the counts for the whole collection.
# the method writeCountFiles can then be used to write the counts to disk.
#
#/twdoc
sub getGlobalCountDocProv {
    my $self = shift;

    if (!defined($self->{globalCountDocProv})) {
	$self->{logger}->debug("globalCountDocProv is undef, Generating DocProvider for global counts") if ($self->{logger});
	my $populated = 0;
	my ($anyDocId, $anyDoc) = each %{$self->{docs}};
	my $obsTypes = $anyDoc->getObsTypesList(); # assuming all docs have the same list of obs types
	my $filename;
	if (defined($self->{globalPath})) {
	    $filename = $self->{globalPath}."/$filePrefixGlobalCount";
	    $self->{logger}->debug("globalPath is defined, looking for global count file under name '$filename'; init obsColl and DocProv") if ($self->{logger});
	    my $globalCountObsColl =  CLGTextTools::ObsCollection->new({ "obsTypes" => $obsTypes, "logging" => defined($self->{logger}), "formatting" => 0, "wordTokenization" => 1 }) ;
	    $self->{globalCountDocProv} = CLGTextTools::DocProvider->new({ "logging" => defined($self->{logger}), "obsCollection" => $globalCountObsColl, "filename" => $filename, "checkIfSourceDocExists" => 0 });
	    $self->{logger}->debug("global count files exist?") if ($self->{logger});
	    if ($self->{globalCountDocProv}->allCountFilesExist()) {
		$self->{logger}->debug("global count files exist, reading these") if ($self->{logger});
		$self->{globalCountDocProv}->readCountFiles();
		$populated = 1;
	    }
	} else {
	    warnLog($self->{logger}, "Warning: DocCollection parameter globalPath not defined, cannot read/write global count files.") if (defined($self->{logger}));
	    $filename  = "/DUMMY-FILENAME";
	}
	if (!$populated) { # either no path defined or no count file found 
	    $self->{logger}->debug("Generating counts at collection level") if ($self->{logger});
	    $self->{logger}->trace("obs types list = (".join(",", @$obsTypes).")") if ($self->{logger});
	    $self->{logger}->debug("Initializing obs coll with finalized data") if ($self->{logger});
	    my $globalCountObsColl =  CLGTextTools::ObsCollection->newFinalized({ "obsTypes" => $obsTypes, "logging" => defined($self->{logger}), "formatting" => 0, "wordTokenization" => 1 }) ;
	    my $allDocs = $self->getDocsAsList();
	    $self->{logger}->debug("Reading all docs data") if ($self->{logger});
	    foreach my $doc (@$allDocs) {
		my $observs = $doc->getObservations();
		my ($obsType, $observsObsType);
		while (($obsType, $observsObsType) = each %$observs) {
		    $globalCountObsColl->addFinalizedObsType($obsType, $observsObsType);
		}
	    }
	    $self->{logger}->debug("Initializing DocProvider") if ($self->{logger});
	    $self->{globalCountDocProv} = CLGTextTools::DocProvider->new({ "logging" => defined($self->{logger}), "obsCollection" => $globalCountObsColl, "filename" => $filename });
	    $self->{globalCountDocProv}->writeCountFiles() if (defined($self->{globalPath}));
	}
    }
    return $self->{globalCountDocProv};
} 



#twdoc getDocFreqCountDocProv($self)
#
# returns a ``DocProvider`` object contaning the counts for the doc frequency table obtained from this collection.
# the method writeCountFiles can then be used to write the counts to disk.
#
#/twdoc
sub getDocFreqCountDocProv {
    my $self = shift;

    if (!defined($self->{docFreqCountDocProv})) {
	$self->{logger}->debug("docFreqCountDocProv is undef, Generating DocProvider for doc freq counts") if ($self->{logger});
	my $populated = 0;
	my ($anyDocId, $anyDoc) = each %{$self->{docs}};
	my $obsTypes = $anyDoc->getObsTypesList(); # assuming all docs have the same list of obs types
	my $filename;
	if (defined($self->{globalPath})) {
	    $filename = $self->{globalPath}."/$filePrefixDocFreqCount";
	    $self->{logger}->debug("globalPath is defined, looking for doc freq count file under name '$filename'; init obsColl and DocProv") if ($self->{logger});
	    my $docFreqCountObsColl =  CLGTextTools::ObsCollection->new({ "obsTypes" => $obsTypes, "logging" => defined($self->{logger}), "formatting" => 0, "wordTokenization" => 1 }) ;
	    $self->{docFreqCountDocProv} = CLGTextTools::DocProvider->new({ "logging" => defined($self->{logger}), "obsCollection" => $docFreqCountObsColl, "filename" => $filename, "checkIfSourceDocExists" => 0 });
	    $self->{logger}->debug("doc freq count files exist?") if ($self->{logger});
	    if ($self->{docFreqCountDocProv}->allCountFilesExist()) {
	    $self->{logger}->debug("doc freq count files exist, reading these") if ($self->{logger});
		$self->{docFreqCountDocProv}->readCountFiles();
		$populated = 1;
	    }
	} else {
	    warnLog($self->{logger}, "Warning: DocCollection parameter globalPath not defined, cannot read/write doc freq count files.") if (defined($self->{logger}));
	    $filename  = "/DUMMY-FILENAME";
	}
	if (!$populated) { # either no path defined or no count file found 
	    $self->{logger}->debug("Generating doc provider for doc freq counts; reading all docs in the collection") if ($self->{logger});
	    $self->{logger}->trace("obs types list = (".join(",", @$obsTypes).")") if ($self->{logger});
	    my @docsObservs;
	    foreach my $docP (values %{$self->{docs}}) {
		push(@docsObservs, $docP->getObservations());
	    }
	    my $docFreqTable = generateDocFreqTable(\@docsObservs, $self->{logger});
	    $self->{logger}->debug("Initializing obs coll with finalized data") if ($self->{logger});
	    my $docFreqCountObsColl =  CLGTextTools::ObsCollection->newFinalized({ "obsTypes" => $obsTypes, "logging" => defined($self->{logger}), "formatting" => 0, "wordTokenization" => 1 }) ;
	    my ($obsType, $observsObsType);
	    while (($obsType, $observsObsType) = each %$docFreqTable) {
		$docFreqCountObsColl->addFinalizedObsType($obsType, $observsObsType);
	    }
	    $self->{logger}->debug("Initializing DocProvider") if ($self->{logger});
	    $self->{docFreqCountDocProv} = CLGTextTools::DocProvider->new({ "logging" => defined($self->{logger}), "obsCollection" => $docFreqCountObsColl, "filename" => $filename });
	    $self->{docFreqCountDocProv}->writeCountFiles() if (defined($self->{globalPath}));
	}
    }
    return $self->{docFreqCountDocProv};
 

}


1;
