package Text::TextAnalytics::Measure::ChiSquare;


use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Log::Log4perl;
use Text::TextAnalytics::Measure::Measure;
use Text::TextAnalytics qw/$indexedNGramClassName/;


our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::Measure/;



=head1 NAME

Text::TextAnalytics::Measure::ChiSquare - Abstract module for chi-square calculation/comparison

ISA=Text::TextAnalytics::Measure::Measure

=head1 DESCRIPTION

This class is "abstract" because there are different ways to compute the chi square score.
However the common parts are coded here, subclasses only have to override
chiSquareScore($nbObservedThisNGram, $nbObservedAllNGrams)

=cut


my %defaultOptions = (  
					   "averageByNumberOfNGrams" => 1, 
					   "incNumberOfNGrams" => 1,
					   "maxDifferenceLength" => -1, 
					   "minCommonNGrams" => 0
					  ); 

my @parametersVars = (
					   "averageByNumberOfNGrams", 
					   "incNumberOfNGrams",
					   "maxDifferenceLength", 
					   "minCommonNGrams"
					 );

=head2 new($class, $params)

must be called by subclasses constructors.

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * averageByNumberOfNGrams: if evaluates to true, then score is (chiSqSum / nbNGramsSeen) ; otherwise it is (chiSqSum / (nbNGramsSeen-1)).  
Default is true, since it is the original method. 

=item * incNumberOfNGrams: adds 1 to the total number of ngrams in both objects. Seems to be a bug but this was the behaviour in the original implementation.
some tests show that the result can be very different depending on this option. default is true.

=item * maxDifferenceLength: compare only segments with similar length (the difference between the lengths is at most this number), and returns NaN otherwise.
A negative value means that this condition is not used (compare any pair of segments).  

=item * minCommonNGrams: compare only segments with at least this number of common ngrams, return NaN otherwise.(0 to compare any pair of segments)

=back

=cut

# TODO I'm not sure that  minCommonNGrams can still be considered as an optimization?

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	return $self;
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

see superclass

=cut

sub requiresSegmentsCountByNGram {

	return 0;	

}



=head2 isASimilarity()

see superclass

=cut

sub isASimilarity {
	return 0;	
}


=head2 score($probeId, $probeData, $refId, $refData)

computes the chi square score for the pair of NGrams objects given as parameters. If these objects are IndexedNGrams, they must share the same index.  
$id1 and $id2 are never used. 

B<Warning:> the returned value can be NaN if parameters are not valid (0 ngrams in one of them or only 1 (same) ngram in both) - depends on the options.  

=cut

sub score {
	my @ngrams;
	my @id;
	my $self;
	($self,$id[0], $ngrams[0], $id[1], $ngrams[1]) = @_;
	my @nbObservedAll;
	my $chiSqSum = 0;
	my %commonNGrams;
#	my %ngramsIndexesUnion;

#	$self->{logger}->info("ids are $id[0] $id[1]");
	$self->{logger}->logconfess("NGrams collections do not share the same index.") if ($ngrams[0]->isa($indexedNGramClassName) && !$ngrams[0]->shareIndexWith($ngrams[1]));
	foreach my $i (0,1) {
		$self->{logger}->debug("NGram $i is ".$ngrams[$i]->valuesAsShortStringWithDetails) if ($self->{debugMode}); # test for efficiency (not to compute the expression)	
		$nbObservedAll[$i] = $ngrams[$i]->getTotalCount();
		$self->{logger}->debug("nbObservedAll[$i] = $nbObservedAll[$i]") if ($self->{debugMode});
		if ($nbObservedAll[$i] == 0) {   # Caution: this test must take place before (possibly) incrementing, because the incremented value is used only in the
                                                 #          calculation of chi square, NOT in the division by the number of ngrams (see use of nbNGramsSeen below)
			$self->{logger}->logcarp("zero ngrams in object $i, returning NaN");
			return "NaN";
		} 
		if ($self->{incNumberOfNGrams}) {
			$nbObservedAll[$i]++;
			$self->{logger}->debug("Incr nbNgrams is ON");	
		} else {
			$self->{logger}->debug("Incr nbNgrams is OFF");	
		}
	}
	$self->{logger}->debug("maxDifferenceLength=".$self->{maxDifferenceLength}.", nbObservedAll[0]=$nbObservedAll[0], nbObservedAll[1]=$nbObservedAll[1]") if ($self->{debugMode}); # test for efficiency (not to compute the expression)	
	if (($self->{maxDifferenceLength}>=0) && (abs($nbObservedAll[0] -$nbObservedAll[1])> $self->{maxDifferenceLength})) {
		$self->{logger}->debug("Returning NaN because length are too different (maxDifferenceLength=".$self->{maxDifferenceLength}.").") if ($self->{debugMode}); # test for efficiency (not to compute the expression)	
		return "NaN";
	}
	my $indexPreprocess = $self->requiresRefNGramsOnly()?1:(($nbObservedAll[0] > $nbObservedAll[1])?0:1);
	my $otherIndex = $indexPreprocess?0:1;
	my $nbCommonNGrams=0;
	my $nextKeyValue = $ngrams[$indexPreprocess]->getKeyValueIterator();
	while (my @keyValuePair = $nextKeyValue->()) {
		my $valueOther = $ngrams[$otherIndex]->getValueFromKey($keyValuePair[0]);
		if (defined($valueOther)) {
			$self->{logger}->trace("Common ngram found: $keyValuePair[0].") if ($self->{debugMode}); # test for efficiency (not to compute the expression)
			$nbCommonNGrams++;
			if ($indexPreprocess) {
				$commonNGrams{$keyValuePair[0]} = [$valueOther, $keyValuePair[1]];
			} else {
				$commonNGrams{$keyValuePair[0]} = [$keyValuePair[1], $valueOther];
			}
		}
	}
	
	$self->{logger}->debug("minCommonNGrams=".$self->{minCommonNGrams}.", nbCommonNGrams=$nbCommonNGrams") if ($self->{debugMode}); # test for efficiency (not to compute the expression)	
	if ($nbCommonNGrams < $self->{minCommonNGrams}) {
		$self->{logger}->debug("Too few common ngrams, returning NaN.") if ($self->{debugMode}); # test for efficiency (not to compute the expression)	
		return "NaN";
	}	
	my $nbNGramsSeen = 0;
	$nextKeyValue = $ngrams[$indexPreprocess]->getKeyValueIterator();
	while (my @keyValuePair = $nextKeyValue->()) { # iterate over the first object ngrams
		$self->{logger}->debug("Current key=$keyValuePair[0]") if ($self->{debugMode});
		$nbNGramsSeen++;
		my @nbObservedThis;
		my $commonNGramValues = $commonNGrams{$keyValuePair[0]};
		if (defined($commonNGramValues)) {
			$nbObservedThis[0] = $commonNGramValues->[0];
			$nbObservedThis[1] = $commonNGramValues->[1];
		} else {
			$nbObservedThis[$indexPreprocess] = $keyValuePair[1];
			$nbObservedThis[$otherIndex] = 0;
		}
		$chiSqSum += $self->chiSquareScore(\@nbObservedThis, \@nbObservedAll);
		$self->{logger}->trace("nbObservedThis[0] = $nbObservedAll[0] ; nbObservedThis[1] = $nbObservedAll[1] ; new chiSqSum = $chiSqSum") if ($self->{debugMode});	
	}
	
	if (!$self->requiresRefNGramsOnly()) { # otherwise not necessary to iterate over the probe ngrams
		$nextKeyValue = $ngrams[$otherIndex]->getKeyValueIterator();
		while (my @keyValuePair = $nextKeyValue->()) { # iterate over the "other object" ngrams
			if (!defined($commonNGrams{$keyValuePair[0]})) { # not already seen
				$nbNGramsSeen++;
				my @nbObservedThis;
				$nbObservedThis[$otherIndex] = $keyValuePair[1];
				$nbObservedThis[$indexPreprocess] = 0;
				$chiSqSum += $self->chiSquareScore(\@nbObservedThis, \@nbObservedAll);
				$self->{logger}->trace("nbObservedThis[0] = $nbObservedAll[0] ; nbObservedThis[1] = $nbObservedAll[1] ; new chiSqSum = $chiSqSum") if ($self->{debugMode});
			}	
		}
	}
	
	$self->{logger}->debug("nbSeen=$nbNGramsSeen, averageByNumberOfNGrams=$self->{averageByNumberOfNGrams}") if ($self->{debugMode});
	# at this step nbNGramsSeen is always > 0 because we would already have returned NaN otherwise.
	my $res;
	if ($self->{averageByNumberOfNGrams}) {
		$res = $chiSqSum / $nbNGramsSeen;
		$self->{logger}->debug("Normalizing by $nbNGramsSeen (nb ngrams), res=$res") if ($self->{debugMode});
# this has been commented out because it's not always true anymore with the chi square variants
# TODO not sure whether the similars warnings around here are still meaningfull
#		if ($nbNGramsSeen == 1) { # if there is only one ngram, $chiSqSum is always zero
#			$self->{logger}->logcarp("Only one ngram seen in chiSquareByDegreeOfFreedomNGrams, result is zero (is it normal?)");
#		}
	} else {
		$nbNGramsSeen--;
		if ($nbNGramsSeen == 0) {
			$self->{logger}->logcarp("Only one ngram seen in chiSquareByDegreeOfFreedomNGrams, returning NaN");
			$res = "NaN";
		} else {
			$res = $chiSqSum / $nbNGramsSeen;
			$self->{logger}->debug("Normalizing by $nbNGramsSeen (nb ngrams -1), res=$res") if ($self->{debugMode});
		}
	}
	return $res;
	
}




=head2 requiresRefNGramsOnly()

ABSTRACT

returns 1 if the class computes score using only ngrams which exist the reference, 0 otherwise

=cut




=head2 chiSquareScore($nbObservedThisNGram, $nbObservedAllNGrams)

ABSTRACT

returns the chi square score for only one ngram given:

=over 2

=item * $nbObservedThisNGram->[0] and $nbObservedThisNGram->[1]: the number of occurrences of THIS ngram in
(resp.) the first (probe) and second (ref) ngrams collection.

=item * $nbObservedAllNGrams->[0] and $nbObservedAllNGrams->[1]: the number of occurrences of ALL ngrams
(in other words the length) in (resp.) the first (probe) and second (ref) ngrams collection. 

=back

must be overriden by subclasses

=cut




1;
