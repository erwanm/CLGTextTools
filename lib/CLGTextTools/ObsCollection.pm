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
use CLGTextTools::Observations::VocabClassObsFamily;;
use Data::Dumper::Simple;
use CLGTextTools::Commons qw/hashKeysToArray readTSVFileLinesAsArray readTextFileLines/;

use base 'Exporter';
our @EXPORT_OK = qw//;

our $decimalDigits = 10;


#
# an ObsCollection may contain more obsTypes than the ones asked as input, because of dependencies.
#
#
#

#
# $params:
# * logging
# * obsTypes (list)
# * wordTokenization = 1 by default; set to 0 if the text is already tokenized (with spaces); applies only to WordFamily observations (POSFamily uses pre-tokenized input, one token by line)
# * wordVocab
# * formatting
# ** no formatting at all: formatting = 0 or undef or empty string
# ** line breaks as meaningful units (e.g. sentences): formatting = singleLineBreak
# ** empty lines (i.e. at least two consecutive line breaks) as meaningful separators (e.g. paragraphs): formatting = doubleLineBreak
# * the formatting does not apply to POS observations
#
#
#
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	$self->{wordTokenization} = 1 unless (defined($params->{wordTokenization}) && ($params->{wordTokenization} == 0));
	$self->{formatting} = $params->{formatting};
	confessLog($self->{logger}, "Invalid value '".$self->{formatting}."' for parameter 'formatting'") if ($self->{formatting} && ($self->{formatting} ne "singleLineBreak") && ($self->{formatting} ne "doubleLineBreak"));
	$self->{families} = {};
	$self->{mapObsTypeToFamily} = {};
	$self->{wordVocab} = $params->{wordVocab};
	bless($self, $class);
	if (defined($params->{obsTypes})) {
	    foreach my $obsType (@{$params->{obsTypes}}) {
		$self->addObsType($obsType);
	    }
	}
	$self->{logger}->trace("initiallized new object: ".Dumper($self)) if ($self->{logger});
	return $self; 	
}


sub addObsType {
    my $self= shift;
    my $obsType = shift;

    my ($family) = ($obsType =~ m/^([^.]+)\./);
    $self->{logger}->debug("Adding obs type '$obsType'; family = '$family'") if ($self->{logger});
    
    if (!defined($self->{families}->{$family})) {
	if ($family eq "WORD") {
	    $self->{families}->{$family} = CLGTextTools::Observations::WordObsFamily->new( {logging => defined($self->{logger}), wordTokenization => $self->{wordTokenization}, vocab => $self->{wordVocab} } );
	} elsif ($family eq "CHAR") {
	    $self->{families}->{$family} = CLGTextTools::Observations::CharObsFamily->new( {logging => defined($self->{logger})} );
	} elsif ($family eq "POS") {
	    $self->{families}->{$family} = CLGTextTools::Observations::POSObsFamily->new({logging => defined($self->{logger})});
	} elsif ($family eq "VOCABCLASS") {
	    $self->{families}->{$family} = CLGTextTools::Observations::VocabClassObsFamily->new({logging => defined($self->{logger}), wordTokenization => $self->{wordTokenization} });
	} else {
	    confessLog($self->{logger}, "Obs types family '$family' not recognized.");
	}
    }
    $self->{mapObsTypeToFamily}->{$obsType} = $family;
    $self->{families}->{$family}->addObsType($obsType);
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

}


#
# TODO
# I don't know how to make it work the same way with POS (and maybe other obs types)?
#
sub addText {
   my $self = shift;
    my $text = shift;

    foreach my $family (keys ($self->{families})) {
	$self->{families}->{$family}->addText($text);
    }
}


sub getNbNGrams {
    my $self = shift;
    my $obsType = shift;
    my $family = $self->{mapObsTypeToFamily}->{$obsType};
    return $self->{families}->{$family}->getNbNGrams($obsType);
}


sub getObservations {
    my $self = shift;
    my $obsType = shift;
    my $family = $self->{mapObsTypeToFamily}->{$obsType};
    return $self->{families}->{$family}->getObservations($obsType);
}

#
# writes <prefix>.<obs>.count and <prefix>.<obs>.total for every obs
# type <obs> in $obstypesList if supplied, or every obs type in the
# objet if not (might include more types in this case, due to
# dependencies).
#
sub writeCountFiles {
    my $self = shift;
    my $prefix = shift;
    my $obsTypesList = shift; # optional

    if (!defined($obsTypesList)) {
	my @obsTypesList = (keys %{$self->{mapObsTypeToFamily}}) ;
	$obsTypesList = \@obsTypesList;
    }
    foreach my $obsType (@$obsTypesList) {
	my $f = "$prefix.$obsType.count";
	my $fh;
	open($fh, ">:encoding(utf-8)", $f) or confessLog($self->{logger}, "Cannot open file '$f' for writing");
	my ($uniqueNGrams, $totalNGrams) = $self->writeObsTypeCount($fh, $obsType);
	close($fh);
	$f = "$prefix.$obsType.total";
	open($fh, ">:encoding(utf-8)", $f) or confessLog($self->{logger}, "Cannot open file '$f' for writing");
	printf $fh "%d\t%d\n", $uniqueNGrams, $totalNGrams;
	close($fh);
    }
}


sub writeObsTypeCount {
    my $self = shift;
    my $fh = shift;
    my $obsType = shift;
    my $columnObsType = shift; # optional: if not undef or 0, adds first column with obs type id

    my $family = $self->{mapObsTypeToFamily}->{$obsType};
    my $observs = $self->{families}->{$family}->getObservations($obsType);
    my $total = $self->{families}->{$family}->getNbNGrams($obsType);
#    while (my ($key, $nb) = each %$observs) {
    foreach my $key (sort keys %$observs) {
	my $nb = $observs->{$key};
	print $fh "%\t" if ($columnObsType);
	printf $fh "%s\t%d\t%.${decimalDigits}f\n", $key, $nb, ($nb/$total) ;
    }
    return (scalar(keys %$observs), $total );
}




1;
