package Text::TextAnalytics::Measure::CosineTFIDF;


use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::NGrams;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics::Measure::Measure;
use Text::TextAnalytics qw/readNGramsFile/;
use Text::TextAnalytics qw/$indexedNGramClassName/;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::Measure/;


=head1 NAME

Text::TextAnalytics::Measure::CosineTFIDF - Module for Cosine TF-IDF measure

TF-IDF = Term Frequency Inverse Document Frequency: the IDF factor is expected to give more weight to rare words/ngrams

ISA = Text::TextAnalytics::Measure::Measure

=cut

=head1 DESCRIPTION


=cut

my %defaultOptions = (  
					   "noIDF" => 0, 
					   "storeNorms" => 1,
					   "loadSegmentCountFromFile" => undef,
					   "segmentCountFilecontainsKeys" => 0
					  ); 

my @parametersVars = (
						"noIDF",
						"storeNorms",
						"loadSegmentCountFromFile",
						"segmentCountFilecontainsKeys"
					 );

our $defaultIDFPenaltyKeyName = "DEFAULT_IDF_PENALTY";


=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * noIDF: compute scores using Term Frequency only

=item * storeNorms: boolean, wether or not to store vector norm (if there is an identifier) in order not to compute it again later.

=item * loadSegmentCountFromFile: if defined, filename of the file from which the segments counts should be read (format: as written by CountNGramsOnlyHLComparator)

=item * segmentCountFilecontainsKeys: if loadSegmentCountFromFile is defined, indicates whether the format includes ngrams keys (default false).

WARNING: if storeNorms is set, the ids must be unique (including between probe/ref!)


=back

=cut


sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{idfVector}->{$defaultIDFPenaltyKeyName} = 1 if ($self->{noIDF});
	return $self;
}


=head2 getName()

see superclass

=cut

sub getName() {
	return "Cosine TF-IDF";	
}


=head2 getParametersString($prefix)

see superclass

=cut

sub getParametersString {
	my ($self, $prefix) = @_;
	my $str = $self->SUPER::getParametersString($prefix);
	$str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars,$prefix, 1);
	return $str;
}


=head2 requiresOrderedNGrams() 

returns false

=cut

sub requiresOrderedNGrams {
	return 0;
}

=head2 requiresUniqueNGrams() 

returns true

=cut

sub requiresUniqueNGrams {
	return 1;
}




=head2 requiresSegmentsCountByNGram()

depends on option noIDF: false if enabled, true otherwise

=cut

sub requiresSegmentsCountByNGram {
	my $self = shift;
	return !($self->{noIDF} || defined($self->{loadSegmentCountFromFile}));	
}



=head2 isASimilarity()

returns true

=cut


sub isASimilarity {
	return 1;	
}



=head2 score($id1, $data1, $id2, $data2)

see superclass

=cut

sub score {
	my @ngrams;
	my @id;
	my $self;
	($self,$id[0], $ngrams[0], $id[1], $ngrams[1]) = @_;

	$self->{logger}->logconfess("NGrams collections do not share the same index.") if (($ngrams[0]->isa($indexedNGramClassName)) && !$ngrams[0]->shareIndexWith($ngrams[1]));
	my $dotProduct = 0;
	$self->{logger}->debug("Starting computing cosine TFIDF for NGram objects [0] ".$ngrams[0]->valuesAsShortString()." and [1] ".$ngrams[1]->valuesAsShortString()) if ($self->{debugMode});
	foreach my $index (@{$ngrams[0]->getKeysListRef()}) {
		my $count1 = $ngrams[1]->getValueFromKey($index);
		if (defined($count1)) {   # for all COMMON ngrams
			my $count0 = $ngrams[0]->getValueFromKey($index);
			if (defined($count0)) {
				my $tfidf0 = $self->computeTFIDFWeight($ngrams[0]->getTotalCount(), $ngrams[0], $index);
				my $tfidf1 = $self->computeTFIDFWeight($ngrams[1]->getTotalCount(), $ngrams[1], $index);
				my $valThis  = $tfidf0 * $tfidf1;
				$dotProduct += $valThis;
				$self->{logger}->trace("common ngram $index: tfidf0=$tfidf0;tfidf1=$tfidf1 -> prodThis=$valThis, dotProduct=$dotProduct") if ($self->{debugMode});
			}
		}
	}
	if ($dotProduct > 0) {
		my @norms;
		$norms[0] = $self->getNorm($id[0], $ngrams[0]);
		$norms[1] = $self->getNorm($id[1], $ngrams[1]);
		my $res = $dotProduct / ($norms[0] * $norms[1]);
		$self->{logger}->debug("Non normalized dot product = $dotProduct, norms=$norms[0];$norms[1] -> cosTFIDF = $res") if ($self->{debugMode});
		return $res;
	}
	$self->{logger}->debug("No common ngram, cosTFIDF = 0") if ($self->{debugMode});
	return 0;
}


=head2 setSegmentsCountByNGram($nbSegments, $SegCount, $anyNGramForSharedIndex)

see parent description.
initializes the IDF vector.
  
=cut

sub setSegmentsCountByNGram {
	my ($self, $nbDocuments, $segCount, $anyNGramForSharedIndex) = @_;
	my $idfVector = {};
	if ($self->{noIDF}) {
		$self->{logger}->debug("IDF set to 1 for all ngrams.") if ($self->{debugMode});
		$idfVector->{$defaultIDFPenaltyKeyName} = 1;
	} else {
		if ($self->{loadSegmentCountFromFile}) {
			$segCount = {};
			($_, $nbDocuments) = readNGramsFile($self->{loadSegmentCountFromFile}, $self->{segmentCountFilecontainsKeys}, undef, $anyNGramForSharedIndex, 1, $segCount); # $ngrams unused
		} 
		$self->{logger}->debug("$nbDocuments documents considered in IDF counts.") if ($self->{debugMode});
		foreach my $idNGram (keys %{$segCount}) {
			$self->{logger}->debug("ngram id '$idNGram': count=".$segCount->{$idNGram}."") if ($self->{debugMode});
			$idfVector->{$idNGram} = $self->computeIDF($segCount->{$idNGram}, $nbDocuments);
			$self->{logger}->debug("ngram id '$idNGram': computed IDF=".$idfVector->{$idNGram}."") if ($self->{debugMode});
		}
		$idfVector->{$defaultIDFPenaltyKeyName} = $self->computeIDF(1, $nbDocuments);
		$self->{logger}->debug("Setting default penalty for unknown ngrams:".$idfVector->{$defaultIDFPenaltyKeyName}." (same value as unique occurrence)") if ($self->{debugMode});
	}
	$self->{idfVector} = $idfVector;
}


#TODO
sub getIDF {
	my $self = shift;
	my $key = shift;
	my $idf = $self->{idfVector}->{$key};
	$idf = $self->{idfVector}->{$defaultIDFPenaltyKeyName} if (!defined($idf));
	return $idf;
}

sub getDefaultIDF {
	my $self = shift;
	return $self->{idfVector}->{$defaultIDFPenaltyKeyName};
}

=head2 getIDFVector()

deprecated but still used for this class

=cut

sub getIDFVector {
	my $self = shift;
	return $self->{idfVector};
}



=head2 getNorm($id, $ngram)

returns the norm of $ngram using the stored value if any, or calculating it otherwise.

WARNING: the ids must be unique (including between probe/ref!)

=cut

sub getNorm {
	my ($self, $id, $ngram) = @_;
	if ($self->{storeNorms} && defined($id) && exists($self->{norms}->{$id})) {
		return $self->{norms}->{$id};
	} else {
		return $self->calculateTFIDFVectorNorm($id, $ngram);
	}
}


=head2 calculateTFIDFVectorNorm($id, $ngram)

Warning: approximation for unknown words using key $defaultIDFPenalty; if not set and unknow words appear, the program will halt with an error.
(which should be defined as the IDF value for a word appearing only once. this is not totally correct wrt to the number of documents) 
 
=cut 

sub calculateTFIDFVectorNorm {
	my ($self, $id, $ngrams) = @_;
	my $sumSqWeights = 0;
	
	my $total = $ngrams->getTotalCount();
	$self->{logger}->debug("calculating TFIDF norm for segment id $id") if ($self->{debugMode});
	foreach my $index (@{$ngrams->getKeysListRef()}) {
		$sumSqWeights += $self->computeTFIDFWeight($total, $ngrams, $index) **2;
	}
	my $res = sqrt($sumSqWeights);
	if ($self->{storeNorms} && defined($id)) {
		$self->{norms}->{$id} = $res;
		$self->{logger}->debug("storing TFIDF norm $res for segment id $id (".scalar(keys %{$self->{storeNorms}})." norms stored)") if ($self->{debugMode});
	}
	return $res;
}


sub computeTFIDFWeight {
	my ($self, $total, $ngrams, $key) = @_;
	my $count = $ngrams->getValueFromKey($key);
	my $idf = $self->{idfVector}->{$key};
	$idf = $self->{idfVector}->{$defaultIDFPenaltyKeyName} if (!defined($idf));
	$self->{logger}->logconfess("No IDF value for ngram id '$key' and no default idf penalty (key $defaultIDFPenaltyKeyName) provided") if (!defined($idf));
	my $weight = $count/$total * $idf;
	$self->{logger}->trace("ngram id '$key': count=$count; totalCount=".$ngrams->getTotalCount()."; IDF=$idf, TF.IDF=$weight") if ($self->{debugMode});
	return $weight;
}

sub computeIDF {
	my ($self, $docCount, $docTotal) = @_;
	return log($docTotal / $docCount); ## compute IDF
}

1;
