package Text::TextAnalytics::Measure::Jaccard;


use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::NGrams;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics::Measure::Measure;
use Text::TextAnalytics qw/$indexedNGramClassName/;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::Measure/;


=head1 NAME

Text::TextAnalytics::Measure::Jaccard - Module for Jaccard index measure


=cut

=head1 DESCRIPTION

ISA = Text::TextAnalytics::Measure::Measure

Jaccard index (or Jaccard coefficient) is based on the number of common ngrams.
It is defined as |A n B| / |A u B|.

=cut

my %defaultOptions = (  
					   "normalize" => 1, 
						"normalizeByProbeOnly" => 0,
						"normalizeByMinLength" => 0,
						"distinctNGrams" => 1
					  ); 

my @parametersVars = (
						"normalize",
						"normalizeByProbeOnly",
						"normalizeByMinLength",
						"distinctNGrams"
					 );



=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * normalize: true by default. If false, the result is |A n B|.

=item * normalizeByProbeOnly: false by default. If true, the result is |A n B | / |A| (where A is the probe segment). unused if normalize disabled.

=item * normalizeByMinLength: false by default. If true, the result is |A n B | / min(|A|,|B|). This formula is sometimes called the overlap coefficient. unused if normalize disabled or normalizeByProbeOnly enabled.

=item * distinctNGrams: true by default, which means that the ngrams frequency (number of occurrences) is not taken into account (original definition with sets). 
If false, multi-sets (a set where the same element can have multiple occurrences) are used instead of sets. Basically this is similar to the Term Frequency measure (depends on normalization). 

=back

=cut


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
	return "Jaccard";	
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
	my ($self, $probeId, $probeNGram, $refId, $refNGram) = @_;
	
	$self->{logger}->logconfess("NGrams collections do not share the same index.") if (($probeNGram->isa($indexedNGramClassName)) && !$probeNGram->shareIndexWith($refNGram));
	
	my $commonDistinctNGramsCount = 0;  
	my $accu = 0;
	$self->{logger}->debug("Starting computing Jacard for NGram objects probe ".$probeNGram->valuesAsShortString()." and ref ".$refNGram->valuesAsShortString()) if ($self->{debugMode});
	foreach my $index (@{$probeNGram->getKeysListRef()}) {
		my $countRef = $refNGram->getValueFromKey($index);
		if (defined($countRef) && ($countRef>0)) {   # for all COMMON ngrams
			my $countProbe = $probeNGram->getValueFromKey($index);
			if (defined($countProbe) && ($countProbe>0)) {
				$commonDistinctNGramsCount++;
#				$accu += $self->{distinctNGrams}?1:$countProbe; # this is to obtain the total count in probe (can be useful only if distinctNGrams=false)
				$accu += $self->{distinctNGrams}?1:_min($countProbe, $countRef);
				$self->{logger}->trace("common ngram $index: counts=$countProbe;$countRef accu=$accu") if ($self->{debugMode});
			}
		}
	}
	my $norma = 1;
	if ($self->{normalize}) {
		if ($self->{normalizeByProbeOnly}) {
			$norma = $self->{distinctNGrams}?$probeNGram->getNbDistinctNGrams():$probeNGram->getTotalCount();
		} else {
			if ($self->{normalizeByMinLength}) {
				$norma = $self->{distinctNGrams}?_min($probeNGram->getNbDistinctNGrams(), $refNGram->getNbDistinctNGrams()):_min($probeNGram->getTotalCount(), $refNGram->getTotalCount());
			} else {
				$norma = $self->{distinctNGrams}?($probeNGram->getNbDistinctNGrams()+$refNGram->getNbDistinctNGrams()-$commonDistinctNGramsCount):($probeNGram->getTotalCount() + $refNGram->getTotalCount());
			}
		}
	}
	my $score="NaN";
	if ($norma > 0) {
	    $score = $accu / $norma;
	} else {
	    $self->{logger}->logwarn("Can not divide by 0 for normalization: choose no normalization, a different normalization or discard empty segments; returning NaN") ;
	}
	$self->{logger}->debug("Jacard final score: $score.") if ($self->{debugMode});
	return $score;	
}


# awful perl trick...
sub _max ($$) { $_[$_[0] < $_[1]] }
sub _min ($$) { $_[$_[0] > $_[1]] }

1;

