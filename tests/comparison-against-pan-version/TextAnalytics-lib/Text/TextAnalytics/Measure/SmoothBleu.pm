package Text::TextAnalytics::Measure::SmoothBleu;


use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::MultiLevelNGrams;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics::Measure::Measure;
use Text::TextAnalytics qw/$indexedNGramClassName/;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::Measure/;


=head1 NAME

Text::TextAnalytics::Measure::Smoothbleu - Smooth Bleu


=cut

=head1 DESCRIPTION

ISA = Text::TextAnalytics::Measure::Measure

TODO explanations

=cut

my %defaultOptions = (  
#						"order" => 4
					  ); 

my @parametersVars = (
#						"order"
					 );

our $multiLevelClassName = "Text::TextAnalytics::NGrams::MultiLevelNGrams";
our $sequenceNGramsClassname = "Text::TextAnalytics::NGrams::SequenceOfNGrams";


=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * TODO

=back

=cut

# TODO

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	return $self;
}


=head2 getName()

see superclass

=cut

sub getName() {
	return "SmoothBLEU";	
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

returns false

=cut

sub requiresSegmentsCountByNGram {
	my $self = shift;
	return 0;
}




=head2 isASimilarity()

true

=cut


sub isASimilarity {
	return 1;	
}



=head2 score($probeId, $probeData, $refId, $refData)

see superclass

=cut


sub score {
	my ($self, $probeId, $probeNGrams, $refId, $refNGrams) = @_;
#	my $multiLevelClassName = "Text::TextAnalytics::NGrams::MultiLevel"
#	$self->logconfess("Invalid NGrams object: the __PACKAGE__ measure only accepts ....");

	my $lengthProbe = $probeNGrams->getTotalCountLevel(0);
	my $lengthRef = $refNGrams->getTotalCountLevel(0);
	if ($lengthProbe == 0) {
		$self->{logger}->logwarn("Warning: empty probe ngram, returning NaN");
		return "NaN";
	}

	my $indexed = ($probeNGrams->isa($indexedNGramClassName)) && ($refNGrams->isa($indexedNGramClassName));
	$self->{logger}->logconfess("NGrams collections do not share the same index.") if ($indexed && !$refNGrams->shareIndexWith($probeNGrams));


	$self->{logger}->logconfess("Both reference and probe NGrams must be MultiLevelNGrams instances.") if (!$refNGrams->isa($multiLevelClassName) || !$probeNGrams->isa($multiLevelClassName));
	my $nbLevels = $refNGrams->getNbLevels();
	$self->{logger}->logconfess("Probe NGrams must have the same number of levels as ref NGrams ($nbLevels).") if ($probeNGrams->getNbLevels() != $nbLevels);

	my $localLogBP = ($lengthProbe < $lengthRef)?(1-$lengthRef/$lengthProbe):0;
	#my @localPrecisions;
	my $localNGramPrecisionScore = 0;
	$self->{logger}->trace("localLogBP = $localLogBP, nbLevels=$nbLevels") if ($self->{debugMode});
	for (my $levelNo=0; $levelNo<$nbLevels; $levelNo++) {
		$self->{logger}->trace("Starting level $levelNo") if ($self->{debugMode});
		my $localPrecision = 0;
		if ($lengthProbe > $levelNo) {
			my $totalLevel = $refNGrams->getTotalCountLevel($levelNo);
			my $probeNgramsKeys = $probeNGrams->getKeysListRefLevel($levelNo);
			$self->{logger}->trace("lengthProbe=$lengthProbe > levelNo, totalLevel=$totalLevel") if ($self->{debugMode});
			my $sumTruePositiveNGrams = 0;
			for my $ngramKey (@$probeNgramsKeys) {
				my $probeValue = $probeNGrams->getValueFromKeyLevel($ngramKey, $levelNo);
				$probeValue = 0 if (!defined($probeValue));
				my $refValue = $refNGrams->getValueFromKeyLevel($ngramKey, $levelNo);
				$self->{logger}->trace("key=$ngramKey, probeValue=$probeValue, refValue=".(defined($refValue)?$refValue:"UNDEF")) if ($self->{debugMode});
				if (!defined($refValue)) {
					$probeValue = 0;
				} elsif ($refValue < $probeValue) {
					$probeValue = $refValue;
				}
				$sumTruePositiveNGrams += $probeValue;			
				$self->{logger}->trace("new probeValue=$probeValue, sumTPNGrams=$sumTruePositiveNGrams") if ($self->{debugMode});
			}
			$localPrecision = ($levelNo==0)?($sumTruePositiveNGrams / $lengthProbe):($sumTruePositiveNGrams+1)/($lengthProbe-$levelNo+1);
			$localNGramPrecisionScore += (1/$nbLevels) * log($localPrecision) if ($localPrecision > 0);			
			$self->{logger}->trace("localPrecision=$localPrecision, localNGramPrecisionScore=$localNGramPrecisionScore") if ($self->{debugMode});
		}
	}
	$self->{logger}->trace("localNGramPrecisionScore=$localNGramPrecisionScore, localLogBP=$localLogBP") if ($self->{debugMode});
	my $finalScore = exp($localLogBP  + $localNGramPrecisionScore);
	$self->{logger}->trace("finalScore=$finalScore") if ($self->{debugMode});
	return $finalScore;
}


1;
