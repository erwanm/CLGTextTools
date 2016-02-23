package CLGTextTools::ObsCollection;

# EM June 2015
# 
#


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


#
# an ObsCollection may contain more obsTypes than the ones asked as input, because of dependencies.
#
# implementation remark: the min freq paramters is dealt with in this class; the obs type id transmitted to the actual family class is stripped from the 'mf<x>' part.
#

#
# $params:
# * logging
# * obsTypes (list, or colon-separated string, or as individual keys: obsType.XXX = 1)
# * wordTokenization = 1 by default; set to 0 if the text is already tokenized (with spaces); applies only to WordFamily observations (POSFamily uses pre-tokenized input, one token by line)
# * wordVocab: vocabulary resources for word class obs types, as a hash; params->{wordVocab}->{resourceId} = resourceValue (usually the value is the source file).
# ** or as individual keys: wordVocab.resourceId = resourceValue
# * formatting
# ** no formatting at all: formatting = 0 or undef or empty string
# ** line breaks as meaningful units (e.g. sentences): formatting = singleLineBreak
# ** empty lines (i.e. at least two consecutive line breaks) as meaningful separators (e.g. paragraphs): formatting = doubleLineBreak
# ** the formatting does not apply to POS observations
#
#
#
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


sub getObsTypes {
    my $self= shift;
    my @obsTypes = keys $self->{mapObsTypeToFamily};
    return \@obsTypes;
}



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
	$self->{typesByFamily}->{$familyId}->{$familyType}->{$obsType} = $minFreq;
    }
    $self->{mapObsTypeToFamily}->{$obsType} = [ $familyId , $familyType ];
}


#
# must be called after all data has been populated, in order to initialize
# 'finalized data' (e.g. apply frequency minima)
#
sub finalize {
    my $self = shift;
    $self->filterMinFreq();
}



#
# * Reads raw text files with one of the following types of formatting:
# ** no formatting at all: $formattingOption = 0 or undef or empty string
# ** line breaks as meaningful units (e.g. sentences): $formattingOption = singleLineBreak
# ** empty lines (i.e. at least two consecutive line breaks) as meaningful separators (e.g. paragraphs): $formattingOption = doubleLineBreak
# * the formatting does not apply to POS observations
#
# * Should be called only after:
# ** the obs types have been initialized (with new or addObsTypes)
# ** resources (e.g. vocabulary) have been initialized (with new)
# * 
# * If POS observations are used, expects a file $filePrefix.POS containing the output in TreeTagger format (with lemma): <token> <POS tag> <lemma>
#
#
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
	    confesLog($self->{logger}, "Bug: missing code for family '$family' ");
	}
    }
    $self->finalize();

}


#
#
sub addText {
   my $self = shift;
    my $text = shift;

    foreach my $family (keys ($self->{families})) {
	$self->{families}->{$family}->addText($text);
    }
}


#
# remark: the number reported is always the original one, no matter the min frequency
#
sub getNbDistinctNGrams {
    my $self = shift;
    my $obsType = shift;
    my $familyIdAndType = $self->{mapObsTypeToFamily}->{$obsType};
    return $self->{families}->{$familyIdAndType->[0]}->getNbDistinctNGrams($familyIdAndType->[1]);
}

#
# remark: the number reported is always the original one, no matter the min frequency
#
sub getNbTotalNGrams {
    my $self = shift;
    my $obsType = shift;
    my $familyIdAndType = $self->{mapObsTypeToFamily}->{$obsType};
    return $self->{families}->{$familyIdAndType->[0]}->getNbTotalNGrams($familyIdAndType->[1]);
}


#
# Returns the observations for a list of obs types as a hash ref:
# h->{obsType}->{ngram} = frequency
# (should be called only after extractObsFromText)
#
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



sub filterMinFreq {
    my $self = shift;
    
    foreach my $familyId (keys %{$self->{families}}) {
	foreach my $familyType (keys %{$self->{typesByFamily}->{$familyId}}) {
	    my $observs1 = $self->{families}->{$familyId}->getObservations($familyType);
	    foreach my $obsType (keys %{$self->{typesByFamily}->{$familyId}->{$familyType}}) {
		my $minFreq = $self->{typesByFamily}->{$familyId}->{$familyType}->{$obsType};
		if ($minFreq <= 1) {
		$self->{finalizedData}->{$obsType} = $observs1;
		} else {
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
