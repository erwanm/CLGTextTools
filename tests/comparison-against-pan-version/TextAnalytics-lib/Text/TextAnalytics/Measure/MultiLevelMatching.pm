package Text::TextAnalytics::Measure::MultiLevelMatching;


use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::MultiLevelNGrams;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics::Measure::Measure;
use Text::TextAnalytics qw/$indexedNGramClassName/;
use Text::TextAnalytics::Measure::Okapi;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::Measure/;


=head1 NAME

Text::TextAnalytics::Measure::MultiLevelMatching - Matching ngram at several levels


=cut

=head1 DESCRIPTION

ISA = Text::TextAnalytics::Measure::Measure

TODO explanations

=cut

my %defaultOptions = (  
						"weightLengthStepDown" => 0.5,
						"weightLengthStepDownAsRatioLength" => 0,
						"localScore" => "exists"
					  ); 

my @parametersVars = (
						"weightLengthStepDown",
						"weightLengthStepDownAsRatioLength",
						"localScore",
						"avgLength"
					 );

# TODO avgLength

our $multiLevelClassName = "Text::TextAnalytics::NGrams::MultiLevelNGrams";
our $sequenceNGramsClassname = "Text::TextAnalytics::NGrams::SequenceOfNGrams";

our %possibleValuesLocalScoreParameter = ( "exists" => 1, "freq" => 1, "logFreq" => 1, "invLogFreq" => 1, "okapiIDF" => 1, "okapiTFIDF" =>1);

=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * TODO

=item * localScore : "exists", "logFreq", "invLogFreq", "freq"

=back

=cut

# TODO

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{logger}->logconfess("Invalid localScore parameter value: '".$self->{localScore}."'") if (!defined($possibleValuesLocalScoreParameter{$self->{localScore}}));
	if ($self->{localScore} =~ m/^okapi/) {
		$self->{logger}->logconfess("Parameter avgLength must be supplied in order to use 'okapi*' scores types") if (!defined($self->{avgLength}));
		$self->{subMeasure}->[0] = Text::TextAnalytics::Measure::Okapi->new({ avgLength => $self->{avgLength} });
	} 
	return $self;
}


=head2 getName()

see superclass

=cut

sub getName() {
	return "MultiLevelMatching";	
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
	return [0,1];
}

=head2 requiresUniqueNGrams() 

returns true

=cut

sub requiresUniqueNGrams {
	return [1,0];
}




=head2 requiresSegmentsCountByNGram()

returns false

=cut

sub requiresSegmentsCountByNGram {
	my $self = shift;
	return ($self->{localScore} =~ m/^okapi/);
}

# TODO
# called only if okapi*
sub setSegmentsCountByNGram {
	my ($self, $nbDocuments, $segCount, $anyNGramForSharedIndex) = @_;
	if ($self->{localScore} =~ m/^okapi/) {
		my $multiLevel = $anyNGramForSharedIndex->isa($multiLevelClassName);
		my $nbLevels = $multiLevel?$anyNGramForSharedIndex->getNbLevels():1;
		if (!$multiLevel) {
			$self->{subMeasure}->[0]->setSegmentsCountByNGram($nbDocuments, $segCount, $anyNGramForSharedIndex);
		} else { # measure 0 already initialized
			for (my $levelNo=1; $levelNo < $nbLevels; $levelNo++) {
				$self->{subMeasure}->[$levelNo] = Text::TextAnalytics::Measure::Okapi->new({ avgLength => $self->{avgLength} });
			}
			for (my $levelNo=0; $levelNo < $nbLevels; $levelNo++) {
				$self->{subMeasure}->[$levelNo]->setSegmentsCountByNGram(ref($nbDocuments)?$nbDocuments->[$levelNo]:$nbDocuments, $segCount->{$levelNo}, $anyNGramForSharedIndex);
			}
		}
	}
}



=head2 isASimilarity()

true

=cut


sub isASimilarity {
	return 1;	
}

sub checkNGramsObjects {
	my ($self, $refNGrams, $probeNGrams) = @_;
	return 1 if ($probeNGrams->isa($sequenceNGramsClassname) && ($probeNGrams->getN() eq "1"));
	return 0;
}


=head2 score($probeId, $probeData, $refId, $refData)

see superclass

=cut

# TODO the shared index between NGrams object is unsafe since there is no check on object classes.

sub score {
	my ($self, $probeId, $probeNGrams, $refId, $refNGrams) = @_;
#	my $multiLevelClassName = "Text::TextAnalytics::NGrams::MultiLevel"
#	$self->logconfess("Invalid NGrams object: the __PACKAGE__ measure only accepts ....");

	if ($probeNGrams->getTotalCount() == 0) {
		$self->{logger}->logwarn("Warning: empty probe ngram, returning NaN");
		return "NaN";
	}

	my $indexed = ($probeNGrams->isa($indexedNGramClassName)) && ($refNGrams->isa($indexedNGramClassName));
	$self->{logger}->logconfess("NGrams collections do not share the same index.") if ($indexed && !$refNGrams->shareIndexWith($probeNGrams));

	my @probeUnigramKeys;
	my $nbprobeUnigramKeys = $probeNGrams->getTotalCount();
	for (my $i=0; $i<$nbprobeUnigramKeys; $i++) {
		$probeUnigramKeys[$i] = $probeNGrams->getNthNGramKey($i);
	}

	my $multiLevel = $refNGrams->isa($multiLevelClassName);
	my $nbLevels = $multiLevel?$refNGrams->getNbLevels():1;

	my %levelsByLength; # TODO
	my @length;
	my @extendedSize;
	my $windowSize = 0;
	my $minLevel = 99999;  
	for (my $levelNo=0; $levelNo < $nbLevels; $levelNo++) {
		$length[$levelNo] = $multiLevel?$refNGrams->getLength($levelNo):$refNGrams->getN();
		$extendedSize[$levelNo] = $multiLevel?$refNGrams->getLevelExtendedSize($levelNo):$length[$levelNo];
		$minLevel = $levelNo if ($extendedSize[$levelNo] < $minLevel); # in case there are not enough ngrams even for the lowest level
		push(@{$levelsByLength{$length[$levelNo]}}, $levelNo);
		$self->{logger}->debug("level $levelNo: length=$length[$levelNo], extendedSize=$extendedSize[$levelNo]") if ($self->{debugMode});
		$windowSize = $length[$levelNo] if ($length[$levelNo] > $windowSize); # find max
	}
	if ($extendedSize[$minLevel] > $nbprobeUnigramKeys) {
		$self->{logger}->logwarn("Not enough ngrams ($nbprobeUnigramKeys) for the lowest level: min level=$minLevel, extended size=$extendedSize[$minLevel]. Returning NaN");
		return "NaN";
	}
	$windowSize = $nbprobeUnigramKeys if ($nbprobeUnigramKeys < $windowSize);
	$self->{logger}->debug("nbProbeUnigramKeys=$nbprobeUnigramKeys, windowSize=$windowSize") if ($self->{debugMode});
	
	my @scores;
	my @values;
	for (my $levelNo=0; $levelNo < $nbLevels; $levelNo++) {  # non optimal: build the complete matrix before computing the score
		my $totalLevel = $refNGrams->getTotalCountLevel($levelNo);
		my $logMaxTotalLevel = log($totalLevel);
#		print "DEBUG $levelNo\n";
		my $currentWindowValue = 0;
		my $currentMaxWindowValue  = 0;
		for (my $i=$nbprobeUnigramKeys-1; $i>=0; $i--) {
			my $ngramKeysList;
			if ($multiLevel) {
				$ngramKeysList = $refNGrams->extractNGramFromPattern($levelNo, \@probeUnigramKeys, $i);
			} elsif ($i+$length[$levelNo] <= $nbprobeUnigramKeys) {
				my @ngram = @probeUnigramKeys[$i .. $i+$length[$levelNo]-1];
				$ngramKeysList = \@ngram;
			}
			if (defined($ngramKeysList)) { # enough unigrams for this ngram
				my $ngramKey = $refNGrams->returnKeyFromList($ngramKeysList);   # TODO VERY VERY VERY DIRTY TRICK! can not work with classes other than HashByGramIndexed...
				my $value = $multiLevel?$refNGrams->getValueFromKeyLevel($ngramKey,$levelNo):$refNGrams->getValueFromKey($ngramKey);
#				print "DEBUG: value for $levelNo, $i = $value\n" if (defined($value));
				if ($self->{localScore} eq "exists") {
					$values[$levelNo]->[$i] = [ $value?1:0 , 1 ]; # if value is >= 1, then 1, otherwise  0 (value is not defined or is 0) ; max =1
				} elsif ($self->{localScore} eq "freq") {
					$values[$levelNo]->[$i] = [ $value?$value:0,  $totalLevel ];
				} elsif ($self->{localScore} eq "logFreq") {
					$values[$levelNo]->[$i] = [ $value?log($value):0,  $logMaxTotalLevel ];
				} elsif ($self->{localScore} eq "invLogFreq") {
					$values[$levelNo]->[$i] = [ $value?log($totalLevel/$value):0,  $logMaxTotalLevel ];
				} elsif ($self->{localScore} eq "okapiIDF") {
					$values[$levelNo]->[$i] = [ $self->{subMeasure}->[$levelNo]->getIDF($ngramKey), $self->{subMeasure}->[$levelNo]->getDefaultIDF() ];
				} elsif ($self->{localScore} eq "okapiTFIDF") { # TODO getIndexedNGramsLevel ???
					$values[$levelNo]->[$i] = [ defined($value)?$self->{subMeasure}->[$levelNo]->computeTFIDFWeight($totalLevel, $refNGrams->getIndexedNGramsLevel($levelNo), $ngramKey):0, $totalLevel * $self->{subMeasure}->[$levelNo]->getDefaultIDF() ];
				} else {
					$self->{logger}->logconfess("Error: invalid localScore parameter '".$self->{localScore}."'");
				}
				$currentWindowValue += $values[$levelNo]->[$i]->[0];
				$currentMaxWindowValue += $values[$levelNo]->[$i]->[1];
				if ($i + $windowSize <= $nbprobeUnigramKeys) {
					if (defined($values[$levelNo]->[$i+$windowSize]) && ($i + $windowSize < $nbprobeUnigramKeys)) {
						$currentWindowValue -= $values[$levelNo]->[$i+$windowSize]->[0];
						$currentMaxWindowValue -= $values[$levelNo]->[$i+$windowSize]->[1];
					}
#					print "DEBUG: scores[$levelNo]->[$i] = [ $currentWindowValue, $currentMaxWindowValue ]\n";
					$scores[$levelNo]->[$i] = [ $currentWindowValue, $currentMaxWindowValue ] ;
				}
			}
		}
	}
	
	# 2. scoring
	my $nbScores = $nbprobeUnigramKeys - $windowSize + 1;
	my $sumScores = 0;
	for (my $i = 0; $i< $nbScores; $i++) {
		my $maxForLength = 0;
		foreach my $length (sort keys %levelsByLength) {
			my ($localScore, $localMax) = (0,0);
			foreach my $levelNo (@{$levelsByLength{$length}})  {
				if (defined($scores[$levelNo]->[$i])) {
					$localScore += $scores[$levelNo]->[$i]->[0];
					$localMax += $scores[$levelNo]->[$i]->[1];
				}
			}
			if ($localMax > 0) {
				my $weight = ($self->{weightLengthStepDownAsRatioLength})?($length / $windowSize):($self->{weightLengthStepDown}**($windowSize - $length));
				my $weightedScore = ($localScore / $localMax ) * $weight; # normalization + weight
				$maxForLength = $weightedScore if ($weightedScore > $maxForLength);
			}
		}
		$sumScores += $maxForLength;
	}
	return $sumScores / $nbScores;	

}


1;
