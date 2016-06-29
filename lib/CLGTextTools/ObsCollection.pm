package CLGTextTools::ObsCollection;

#twdoc 
#
# This class represents a collection of observations from different observations types, these being themselves organized into different observations families. 
# The class deals with calling the right family function to extract observations from a raw text (possibly using additional resources), in a way as efficient as possible (for intance,
# by avoiding reading the source document several times for each obs type or family).
#
# * An ``ObsCollection`` may contain more obsTypes than the ones asked as input, because of dependencies.
# * implementation remark: the min freq paramters is dealt with in this class; the obs type id transmitted to the actual family class is stripped from the ``mf<x>`` part.
#
# ---
# EM June 2015
# 
#/twdoc


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog/;
use CLGTextTools::Observations::WordObsFamily;
use CLGTextTools::Observations::CharObsFamily;
use CLGTextTools::Observations::POSObsFamily;
use CLGTextTools::Observations::VocabClassObsFamily;
use Data::Dumper::Simple;
use CLGTextTools::Commons qw/hashKeysToArray readTSVFileLinesAsArray readTextFileLines readObsTypesFromConfigHash readParamGroupAsHashFromConfig assignDefaultAndWarnIfUndef/;

use base 'Exporter';
our @EXPORT_OK = qw/extractObservsWrapper/;

our $decimalDigits = 12;


#twdoc new($class, $params)
#
#
# ``$params``:
#
# * logging
# * obsTypes (list, or colon-separated string, or as individual keys: obsType.XXX = 1)
# * wordTokenization = 1 by default; set to 0 if the text is already tokenized (with spaces); applies only to WordFamily observations (POSFamily uses pre-tokenized input, one token by line)
# * wordVocab: vocabulary resources for word class obs types, as a hash; ``params->{wordVocab}->{resourceId} = resourceValue`` (usually the value is the source file).
# ** or as individual keys: wordVocab.resourceId = resourceValue
# * formatting
# ** no formatting at all: formatting = 0 or undef or empty string
# ** line breaks as meaningful units (e.g. sentences): formatting = singleLineBreak
# ** empty lines (i.e. at least two consecutive line breaks) as meaningful separators (e.g. paragraphs): formatting = doubleLineBreak
# ** the formatting does not apply to POS observations
#
#
#/twdoc
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	$self->{wordTokenization} = assignDefaultAndWarnIfUndef("wordTokenization", $params->{wordTokenization}, 1, $self->{logger});
	$self->{formatting} = assignDefaultAndWarnIfUndef("formatting", $params->{formatting}, 0, $self->{logger});
	confessLog($self->{logger}, "Invalid value '".$self->{formatting}."' for parameter 'formatting'") if ($self->{formatting} && ($self->{formatting} ne "singleLineBreak") && ($self->{formatting} ne "doubleLineBreak"));
	$self->{families} = {};
	$self->{typesByFamily} = {};
	$self->{mapObsTypeToFamily} = {};
	$self->{wordVocab} = (ref($params->{wordVocab}) eq "HASH") ? $params->{wordVocab} : readParamGroupAsHashFromConfig($params, "wordVocab");
	bless($self, $class);
	my $obsTypes = (defined($params->{obsTypes}) && ref($params->{obsTypes}) eq "ARRAY") ? $params->{obsTypes} : readObsTypesFromConfigHash($params);
	foreach my $obsType (@$obsTypes) {
	    $self->addObsType($obsType);
	}
	$self->{finalizedData} = undef;
	$self->{logger}->trace("initiallized new object: ".Dumper($self)) if ($self->{logger});
	return $self; 	
}


#twdoc newFinalized($class, $params)
#
# Creates a pre-populated obs collection object. To be used with ``addFinalizedObsType()``. Used only in a few specific cases (see ``DocCollection``).
#
#
# $params:
#
# * logging
# * obsTypes (list, or colon-separated string, or as individual keys: obsType.XXX = 1)
#
#/twdoc
sub newFinalized {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	my $obsTypes = (defined($params->{obsTypes}) && ref($params->{obsTypes}) eq "ARRAY") ? $params->{obsTypes} : readObsTypesFromConfigHash($params);
	foreach my $obsType (@$obsTypes) {
	    $self->{mapObsTypeToFamily}->{$obsType} = 1; # dummy value (mapObsTypeToFamily must be initialized in order to store obs types and return them through getObsTypes)
	}
	# these parameters and data structures are not needed and should not be used
	$self->{wordTokenization} = undef;
	$self->{formatting} = undef;
	$self->{families} = {};
	$self->{typesByFamily} = {};
	$self->{wordVocab} = undef;
	$self->{finalizedData} = {};
	$self->{nbNGramsTotal} = {}; # special for finalized version!!
	bless($self, $class);
	$self->{logger}->trace("initiallized new object: ".Dumper($self)) if ($self->{logger});
	return $self; 	
}


#twdoc addFinalizedObsType($self, $obsType, $observs)
#
# Adds a set of observations for one obs type to the collection. The data is considered "finalized".
# ``$self->{nbNGramsTotal}`` is updated accordingly.
#
# * ``$observs``: hash ``$observs->{obs} = freq``
#
#/twdoc
sub addFinalizedObsType {
    my $self = shift;
    my $obsType = shift;
    my $observs = shift;
    
    my ($obs, $freq);
    while (($obs, $freq) = each %$observs) {
	$self->{finalizedData}->{$obsType}->{$obs} += $freq;
	$self->{nbNGramsTotal}->{$obsType} += $freq;
    }
}



#twdoc getObsTypes($self)
#
# Returns the list of obs types.
#
#/twdoc
sub getObsTypes {
    my $self= shift;
    my @obsTypes = keys %{$self->{mapObsTypeToFamily}};
    return \@obsTypes;
}



#twdoc addObsType($self, $obsType)
#
# Adds an obs type to the list of obs types to process. The obs type string is parsed:
#
# # the min freq suffix ``.mf<N>`` is removed to be taken care of later;
# # the prefix is extracted, in order to find the family the obs type belongs to;
# # the appropriate family constructor is called (with the relevant parameters, including possible resources)
#
#/twdoc
sub addObsType {
    my $self= shift;
    my $obsType = shift;

    $self->{logger}->debug("Init ObsCollection object: adding obs type '$obsType'") if ($self->{logger});
    my ($familyId, $params, $minFreq) = ($obsType =~ m/^([^.]+)\.(.*)\.mf(\d+)$/);
    $self->{logger}->debug("Adding obs type '$obsType'; familyId = '$familyId', minFreq='$minFreq', params='$params'") if ($self->{logger});
    if (!defined($self->{families}->{$familyId})) {
	if ($familyId eq "WORD") {
	    $self->{families}->{$familyId} = CLGTextTools::Observations::WordObsFamily->new( {logging => defined($self->{logger}), wordTokenization => $self->{wordTokenization}, vocab => $self->{wordVocab} } );
	} elsif ($familyId eq "CHAR") {
	    $self->{families}->{$familyId} = CLGTextTools::Observations::CharObsFamily->new( {logging => defined($self->{logger})} );
	} elsif ($familyId eq "POS") {
	    $self->{families}->{$familyId} = CLGTextTools::Observations::POSObsFamily->new({logging => defined($self->{logger})});
	} elsif ($familyId eq "VOCABCLASS") {
	    $self->{families}->{$familyId} = CLGTextTools::Observations::VocabClassObsFamily->new({logging => defined($self->{logger}), wordTokenization => $self->{wordTokenization} });
	} else {
	    confessLog($self->{logger}, "Obs types family id '$familyId' not recognized.");
	}
    }

    my $familyType = "$familyId.$params";
    if (!defined($self->{typesByFamily}->{$familyId}->{$familyType})) {
	$self->{families}->{$familyId}->addObsType($familyType);
    }
    $self->{typesByFamily}->{$familyId}->{$familyType}->{$obsType} = $minFreq;
    $self->{mapObsTypeToFamily}->{$obsType} = [ $familyId , $familyType ];
}


#twdoc finalize($self)
#
# * Must be called after all data has been populated, in order to initialize 'finalized data' (e.g. apply frequency minima)
#
#/twdoc
sub finalize {
    my $self = shift;
    $self->filterMinFreq();
}


#twdoc  extractObsFromText($self, $filePrefix)
#
# * Reads a raw text file ``$filePrefix`` with one of the following types of formatting:
# ** no formatting at all: $formattingOption = 0 or undef or empty string
# ** line breaks as meaningful units (e.g. sentences): $formattingOption = singleLineBreak
# ** empty lines (i.e. at least two consecutive line breaks) as meaningful separators (e.g. paragraphs): $formattingOption = doubleLineBreak
# * the formatting does not apply to POS observations
#
# * Should be called only after:
# ** the obs types have been initialized (with ``new`` and/or ``addObsTypes``)
# ** resources (e.g. vocabulary for word observations) have been initialized (with ``new``)
# 
# After extracting all the observations, the data is "finalized", which includes applying the minimum individual frequency thresholds.
#
# * If POS observations are used, expects a file ``$filePrefix.POS`` containing the output in TreeTagger format (with lemma): ``<token> <POS tag> <lemma>``
#
#/twdoc
sub extractObsFromText {
    my $self = shift;
    my $filePrefix = shift;

    my $textUnits;
    foreach my $family (keys %{$self->{families}}) {
	$self->{logger}->debug("Extracting observations for family '$family'") if ($self->{logger});
	if ( ($family eq "WORD") || ($family eq "CHAR") || ($family eq "VOCABCLASS") ) {
	    if (!defined($textUnits)) { # avoid reading text for every family
		$self->{logger}->debug("reading file '$filePrefix'") if ($self->{logger});
		my $textLines = readTextFileLines($filePrefix,1,$self->{logger}); # remark: removing EOL characters
		if ($self->{formatting}) {
		    if ($self->{formatting} eq "singleLineBreak") {
			$self->{logger}->debug("formatting: separator = single line break") if ($self->{logger});
			$textUnits = $textLines;
		    } elsif ($self->{formatting} eq "doubleLineBreak") {
			$self->{logger}->debug("formatting: separator = double line break") if ($self->{logger});
			my $currentUnit = "";
			for (my $i = 0; $i < scalar(@$textLines); $i++) {
			    if (length($textLines->[$i])>0) {
				$currentUnit .= $textLines->[$i];
			    } else {
				push(@$textUnits, $currentUnit) if (length($currentUnit)>0);
				$self->{logger}->trace(" new unit (double line break): '$currentUnit'") if ($self->{logger});
				$currentUnit = "";
			    }
			}
			push(@$textUnits, $currentUnit) if (length($currentUnit)>0);
		    } else {
			confessLog($self->{logger}, "Bug: invalid value '".$self->{formatting}."' for parameter 'formatting'");			
		    }		    
		} else {
		    $self->{logger}->debug("raw text, no formatting") if ($self->{logger});
		    $textUnits = [ join(" ", @$textLines) ];
		}
	    }
	    foreach my $unit (@$textUnits) {
		$self->{families}->{$family}->addText($unit);
	    }
	} elsif ($family eq "POS") {
	    $self->{logger}->debug("reading file '$filePrefix.POS'") if ($self->{logger});
	    my $textLines = readTSVFileLinesAsArray("$filePrefix.POS", 3, $self->{logger});
	    $self->{families}->{$family}->addText($textLines);
	} else {
	    confessLog($self->{logger}, "Bug: missing code for family '$family' ");
	}
    }
    $self->finalize();

}


#twdoc addText($self, $text)
#
# Adds the observations found in ``$text`` to the current sets of observations for every obs type.
#
#
#/twdoc
sub addText {
   my $self = shift;
    my $text = shift;

    foreach my $family (keys %{$self->{families}}) {
	$self->{families}->{$family}->addText($text);
    }
}


#twdoc getNbDistinctNGrams($self, $obsType)
#
# Returns the number of distinct observations (i.e. not counting multiple occurrences) for ``$obsType``.
#
# * Remark: the reported number is always the original one, no matter the min frequency
#
#/twdoc
sub getNbDistinctNGrams {
    my $self = shift;
    my $obsType = shift;
    if (defined($self->{nbNGramsTotal})) { # special case for pre-populated obs collection
	return scalar(keys %{$self->{finalizedData}->{$obsType}});
    } else {
	my $familyIdAndType = $self->{mapObsTypeToFamily}->{$obsType};
	return $self->{families}->{$familyIdAndType->[0]}->getNbDistinctNGrams($familyIdAndType->[1]);
    }
}

#twdoc getNbTotalNGrams($self, $obsType)
#
# Returns the total number of observations (i.e. taking multiple occurrences into account) for ``$obsType``.
#
# * Remark: the reported number is always the original one, no matter the min frequency
#
#/twdoc
sub getNbTotalNGrams {
    my $self = shift;
    my $obsType = shift;

    if (defined($self->{nbNGramsTotal})) { # special case for pre-populated obs collection
	return $self->{nbNGramsTotal}->{$obsType};
    } else {
	my $familyIdAndType = $self->{mapObsTypeToFamily}->{$obsType};
	return $self->{families}->{$familyIdAndType->[0]}->getNbTotalNGrams($familyIdAndType->[1]);
    }
}


#twdoc isFinalized($self)
#
# returns true if and only if the obs collection has been populated and finalized
#
#/twdoc
sub isFinalized {
    my $self = shift;
    return defined($self->{finalizedData});
}


#twdoc getObservations($self, $obsTypesList)
#
# Returns the observations for a list of obs types as a hash ref ``h->{obsType}->{ngram} = frequency``
# (should be called only after ``extractObsFromText``, i.e. after the data has been finalized)
#
#/twdoc
sub getObservations {
    my $self = shift;
    my $obsTypesList = shift;

    my %res;
    confessLog($self->{logger}, "Error: obs collection has not been finalized yet.") if (!defined($self->{finalizedData}));
    foreach my $obsType (@$obsTypesList) {
	$res{$obsType} = $self->{finalizedData}->{$obsType};
	confessLog($self->{logger}, "Error: invalid observation type '$obsType'; no such type found in the collection.") if (!defined($res{$obsType}));
    }
    return \%res;
}



#twdoc filterMinFreq($self)
#
# For every obs type ``XXX.mf<minFreq>``, filters out thr observations which do not appear at least ``<minFreq>`` times.
#
# * Called when the data is finalized.
#
#/twdoc
sub filterMinFreq {
    my $self = shift;
    
    foreach my $familyId (keys %{$self->{families}}) {
	$self->{logger}->debug("filter min freq for family '$familyId'") if ($self->{logger});
	foreach my $familyType (keys %{$self->{typesByFamily}->{$familyId}}) {
	    $self->{logger}->debug("filter min freq for family '$familyId', family type = '$familyType'") if ($self->{logger});
	    my $observs1 = $self->{families}->{$familyId}->getObservations($familyType);
	    foreach my $obsType (keys %{$self->{typesByFamily}->{$familyId}->{$familyType}}) {
		my $minFreq = $self->{typesByFamily}->{$familyId}->{$familyType}->{$obsType};
		$self->{logger}->debug("filter min freq for family '$familyId', family type = '$familyType', obs type = '$obsType'") if ($self->{logger});
		if ($minFreq <= 1) {
		    $self->{logger}->debug("obs type = '$obsType': min freq <= 1, keeping all observations") if ($self->{logger});
		    $self->{finalizedData}->{$obsType} = $observs1;
		} else {
		    $self->{logger}->debug("obs type = '$obsType': min freq = $minFreq, filtering") if ($self->{logger});
		    my ($key, $freq, %res);
		    while (($key, $freq) = each (%$observs1)) {
			$res{$key} = $freq if ($freq >= $minFreq);
		    }
		    $self->{finalizedData}->{$obsType} = \%res;
		    
		}
	    }
	}
    }
}




1;
