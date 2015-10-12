package Text::TextAnalytics::ScoresConsumer::RankingScoresConsumer;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics qw/$prefixModuleMeasure/;
use Text::TextAnalytics::ScoresConsumer::ScoresConsumer;

use Text::TextAnalytics::Util qw/rankWithTies/;

our @ISA = qw/Text::TextAnalytics::ScoresConsumer::ScoresConsumer/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::ScoresConsumer::RankingScoresConsumer - computes the final ranking.

=head1 DESCRIPTION

sends the arguments received after sorting them and adds a rank argument. The scores are
sent (as output) sorted by their rank order.

=cut

our $defaultEncoding = "utf-8";

my %defaultOptions = ( 
					   "valuesArgNo" => undef,
					   "highestFirst" => 0,
					   "lowestFirst" => 0,
					   "mostSimilarFirst" => 1,
					   "NaNScoresAsLeastSimilar" => 1,
					   "noNaNWarning" => 0,
					   "storeRanking" => 0,
					   "sendOnlyNBest" => 0
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
our @parametersVars = (
					   "valuesArgNo",
					   "highestFirst",
					   "lowestFirst",
					   "mostSimilarFirst",
					   "NaNScoresAsLeastSimilar",
					   "noNaNWarning",
					   "storeRanking",
					   "sendOnlyNBest"
					  );



=head2 new($class, $params)


$params is a hash ref which optionaly defines:
 
=over 2

=item * valuesArgNo: arg no for the values to rank from. If undef (default), the last arg is used.

=item * highestFirst: ranking by descending order if true. see also mostSimilarFirst below. default: false.

=item * lowestFirst: ranking by ascending order if true. see also mostSimilarFirst below. default: false.

=item *  mostSimilarFirst: boolean, true by default. if both highestFirst and lowestFirst are false, indicates the order in which the
ranking takes place w.r.t the measure which was used: set to false to rank from least similar to most similar. Parameter hlComparator MUST
be defined in this case. Unused otherwise (if either highestFirst or lowestFirst is true).

=item * hlComparator: the HighLevelComparator object containing the measure which was used to compute the scores. This parameter MUST be
provided if both highestFirst and lowestFirst are false (see above), and is unused otherwise.

=item * NaNScoresAsLeastSimilar: boolean, true by default: the NaN values are considered as the least similar 
scores and included in the ranking (at the beginning or the end depending on mostSimilarFirst). if disabled, the NaN values are discarded.
 
=item * noNaNWarning: 0 by default, which means that a warning is issued if NaN values are found. This does not happen if this parameter is set to true.

=item * storeRanking: By default the ranking is not stored after it has been sent to the next consumer. If this parameter is enabled, 
the ranking is stored and accessible with getRanking() (or getRank($probeId, $refId)). 

=item * sendOnlyNBest: if this parameter N is higher than 0, then only the N best scores (according to the rank) will be sent as output.
		In the case of ties, the selection is arbitrary (e.g. if N=10 and values are equal from rank 8 to 12, then only 3 values among these 5 will be sent).
		The default value is zero, which means that all scores are sent.
		 
=back

=cut
sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $param (keys %defaultOptions) {
		$self->{$param} = $defaultOptions{$param} if (!defined($self->{$param}));
	}
	$self->{logger}->logconfess("Parameter hlComparator must be defined if neither highestFirst nor lowestFirst are true.") if (!defined($self->{hlComparator}) && !$self->{highestFirst} && !$self->{lowestFirst});
	$self->{ids} = [];
	$self->{values} = {};
	return $self; 	
}



=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = $self->SUPER::getParametersString($prefix);
	$str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars,$prefix, 1);
	$self->{scores} = {};
	return $str;
}


=head 2 receiveScore(@data)

see superclass 

=cut

sub receiveScore {
	my $self = shift;
	my $value;
	$self->{logger}->logconfess("Less than two arguments (args=".join(";",@_).") received in ranking consumer.") if (scalar(@_)<2);
	if (defined($self->{valuesArgNo})) {
		$self->{logger}->logconfess("Parameter valuesArgNo=".$self->{valuesArgNo}.", but only ".scalar(@ARGV)." arguments found .") if (scalar(@_)<=$self->{valuesArgNo});
		$value = $_[$self->{valuesArgNo}];
	} else {
		$value = $_[scalar(@_)-1];
	}
	my @data = @_;
	push(@{$self->{ids}}, \@data);
#	print STDERR "data=".join(";",@data)." - id=".(scalar(@{$self->{ids}})-1)." - score = $value\n";
	$self->{values}->{scalar(@{$self->{ids}})-1} =  $value;
}


=head2 getValues()

returns the hash ref containing all scores received so far.

=cut

sub getValues {
	my $self = shift;
	return $self->{values};
}



=head2 getRanking()

returns the hash ref containing the ranking (if finalize() has already been called)

=cut

sub getRanking {
	my $self = shift;
	return $self->{ranking};
}





=head2 finalize($footer)

see superclass 

=cut

sub finalize {
	my ($self, $footer) = @_;
	my $decreasingOrder;
	if (!$self->{highestFirst} && !$self->{lowestFirst}) {
		my $measureIsASimilarity = $self->{hlComparator}->getMeasure()->isASimilarity();
		$decreasingOrder = ($self->{"mostSimilarFirst"} && $measureIsASimilarity) ||  (!$self->{"mostSimilarFirst"} && !$measureIsASimilarity);
	} else {
		$decreasingOrder = $self->{highestFirst};
	}
	my $NaNValuesBefore = ($self->{NaNScoresAsLeastSimilar} && !$self->{"mostSimilarFirst"});
	my $NaNValuesAfter = ($self->{NaNScoresAsLeastSimilar} && $self->{"mostSimilarFirst"});
	my $ranking  = rankWithTies({ values => $self->{values} , 
										highestValueFirst =>$decreasingOrder, 
										noNaNWarning => $self->{noNaNWarning},
										addNaNValuesBefore => $NaNValuesBefore,
										addNaNValuesAfter => $NaNValuesAfter,
	});
	$self->{ranking} = $ranking;
	if (defined($self->{nextConsumer})) {
		$self->{logger}->debug("Sorting by rank and sending data to next consumer...");
		my $nbSent=0;
		foreach my $id (sort {$ranking->{$a} <=> $ranking->{$b}} keys %{$self->{ranking}}) {
			if (($self->{sendOnlyNBest}>0) && ($nbSent>=$self->{sendOnlyNBest})) {
				last;
			}
			my @data = @{$self->{ids}->[$id]};
			push(@data, $ranking->{$id});
			$self->{nextConsumer}->receiveScore(@data);
		}
		if (($self->{sendOnlyNBest}>0) && ($nbSent<$self->{sendOnlyNBest})) {
			$self->{logger}->logwarn("Can not send ".$self->{sendOnlyNBest}." scores because only $nbSent were received");
		}
	}
	$self->{ranking} = undef unless ($self->{storeRanking});
	$self->SUPER::finalize($footer);
}




1;


