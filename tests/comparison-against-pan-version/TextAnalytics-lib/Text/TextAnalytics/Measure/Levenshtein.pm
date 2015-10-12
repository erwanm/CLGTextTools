package Text::TextAnalytics::Measure::Levenshtein;


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

Text::TextAnalytics::Measure::Levenshtein - Module for Levenshtein distance


=head1 DESCRIPTION

Levenshtein distance: counts the minimum number of insertions/deletions/substitutions needed to transform a sequence into another (symetrical)

ISA = Text::TextAnalytics::Measure::Measure

=cut

my %defaultOptions = (  
					   "normalize" => 1, 
					   "permitTransposition" => 0
					  ); 

my @parametersVars = (
						"normalize",
						"permitTransposition"
					 );



=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * normalize: boolean, normalize the distance score (division by longest length); true by default

=item * permitTransposition: boolean, add the transposition operation (ab -> ba); default is false

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
	return "Levenshtein";	
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

returns true

=cut

sub requiresOrderedNGrams {
	return 1;
}

=head2 requiresUniqueNGrams() 

returns false

=cut

sub requiresUniqueNGrams {
	return 0;
}




=head2 requiresSegmentsCountByNGram()

returns false

=cut

sub requiresSegmentsCountByNGram {
	return 0;	
}



=head2 isASimilarity()

returns false

=cut


sub isASimilarity {
	return 0;	
}



=head2 score($id1, $data1, $id2, $data2)

see superclass

=cut

sub score {
	my ($self,$idProbe, $ngramsProbe, $idRef, $ngramsRef) = @_;

	$self->{logger}->logconfess("NGrams collections do not share the same index.") if (($ngramsProbe->isa($indexedNGramClassName)) && !$ngramsProbe->shareIndexWith($ngramsRef));
	my $probeLength = $ngramsProbe->getTotalCount();
	my $refLength = $ngramsRef->getTotalCount();
	
	my %d;
	$self->{logger}->debug("probe/ref length = $probeLength/$refLength. initializing matrix") if ($self->{debugMode});
	for (my $i = 0; $i <= $probeLength; $i++) {
		$d{"$i,0"} = $i;
	}
	for (my $j = 0; $j <= $refLength; $j++) {
		$d{"0,$j"} = $j;
	}
	for (my $i = 1; $i <= $probeLength; $i++) {
		my $ngramProbe = $ngramsProbe->getNthNGramKey($i-1);
		for (my $j = 1; $j <= $refLength; $j++) {
			my $ngramRef = $ngramsRef->getNthNGramKey($j-1);
			if ($ngramProbe eq $ngramRef) {
				$d{$i.",".$j} = $d{($i-1).",".($j-1)}
			} else {
				my $min1 = _min($d{($i-1).",".$j}+1, $d{$i.",".($j-1)}+1);
				if ($self->{permitTransposition} && ($i>1) && ($j>1)) {
					my $prevProbe = $ngramsProbe->getNthNGramKey($i-2);
					my $prevRef = $ngramsRef->getNthNGramKey($j-2);
					$min1 = _min($min1, $d{($i-2).",".($j-2)}+1) if (($ngramProbe eq $prevRef) && ($ngramRef eq $prevProbe));
				}
				$d{$i.",".$j} = _min($min1, $d{($i-1).",".($j-1)}+1);
			}
		}
	}
	my $score = $d{$probeLength.",".$refLength};
	$self->{logger}->debug("score before possibly normalizing = $score") if ($self->{debugMode});
	$score /= _max($probeLength, $refLength) if ($self->{normalize} && (($probeLength >0) || ($refLength>0)));
	$self->{logger}->debug("final score = $score") if ($self->{debugMode});
	return $score;
}


sub _min {
	return ($_[0]<$_[1])?$_[0]:$_[1];
}

sub _max {
	return ($_[0]<$_[1])?$_[1]:$_[0];
}

1;
