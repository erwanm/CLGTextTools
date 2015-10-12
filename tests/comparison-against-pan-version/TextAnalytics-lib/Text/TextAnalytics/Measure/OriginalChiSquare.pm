package Text::TextAnalytics::Measure::OriginalChiSquare;


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Text::TextAnalytics::Measure::ChiSquare;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::ChiSquare/;



=head1 NAME

Text::TextAnalytics::Measure::OriginalChiSquare - as its name suggests

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
	return "chi-square (original)";	
}



=head2 chiSquareScore($nbObservedArray, $nbTotalArray)

see description in parent class

=cut

sub chiSquareScore {
	my ($self, $nbObservedThisNGram, $nbObservedAllNGrams) = @_;
	
	my $totalObservedThis = $nbObservedThisNGram->[0] + $nbObservedThisNGram->[1];
	my $totalObservedAll =  $nbObservedAllNGrams->[0] + $nbObservedAllNGrams->[1];
	my @chiSquare;
	foreach my $i (0,1) {
		my $nbExpectedThis = $totalObservedThis * $nbObservedAllNGrams->[$i] / $totalObservedAll;
		$self->{logger}->logconfess("expected value=0! Can not compute chi2") if ($nbExpectedThis==0);
		$chiSquare[$i] = 	(($nbObservedThisNGram->[$i] - $nbExpectedThis)**2/$nbExpectedThis);
		if ($self->{debugMode}) { # test for efficiency (not to compute the expression) 
			$self->{logger}->trace("total NbObsThis $i=$nbObservedThisNGram->[$i]; nbObsAll $i=$nbObservedAllNGrams->[$i]; total=$totalObservedAll; nbExpected $i=$nbExpectedThis; chisq = $chiSquare[$i]")
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
