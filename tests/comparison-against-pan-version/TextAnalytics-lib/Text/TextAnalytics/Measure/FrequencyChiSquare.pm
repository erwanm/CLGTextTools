package Text::TextAnalytics::Measure::FrequencyChiSquare;


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Text::TextAnalytics::Measure::ChiSquare;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::ChiSquare/;



=head1 NAME

Text::TextAnalytics::Measure::FrequencyChiSquare - in this variant the relative frequencies are used instead of the counts.

ISA = Text::TextAnalytics::Measure::ChiSquare

=head1 DESCRIPTION

=cut

=head2 new($class, $params)

no specific parameter, see parent description

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	return $self; 	
}



=head2 getName()

see description in parent class

=cut

sub getName() {
	return "chi-square (frequency)";	
}



=head2 chiSquareScore($nbObservedArray, $nbTotalArray)

see description in parent class

=cut

sub chiSquareScore {
	my ($self, $nbObservedThisNGram, $nbObservedAllNGrams) = @_;
	
	my $freqExpected = ($nbObservedThisNGram->[0] + $nbObservedThisNGram->[1]) / ($nbObservedAllNGrams->[0] + $nbObservedAllNGrams->[1]);
	my @chiSquare;
	foreach my $i (0,1) {
		my $freqObserved = $nbObservedThisNGram->[$i] / $nbObservedAllNGrams->[$i];
		$chiSquare[$i] = 	($freqObserved - $freqExpected)**2/ $freqExpected;
		if ($self->{debugMode}) { # test for efficiency (not to compute the expression) 
			$self->{logger}->trace("i=$i ; freqExpected = $freqExpected ; freqObserved = $freqObserved ; chisq = $chiSquare[$i]")
		}
	}
	return $chiSquare[0] + $chiSquare[1];
}


=head2 requiresRefNGramsOnly()

see description in parent class

=cut

sub requiresRefNGramsOnly {
  return 0;
}


1;
