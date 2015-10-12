package Text::TextAnalytics::Measure::DirectedChiSquare;


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Text::TextAnalytics::Measure::ChiSquare;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::ChiSquare/;



=head1 NAME

Text::TextAnalytics::Measure::DirectedChiSquare - the expected value is based on the ref text only.

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
	return "chi-square (directed)";	
}



=head2 chiSquareScore($nbObservedArray, $nbTotalArray)

see description in parent class

=cut

sub chiSquareScore {
	my ($self, $nbObservedThisNGram, $nbObservedAllNGrams) = @_;
	
	# expected = nbRef / totalRef * totalProbe ; observed = nbProbe
	my $expected = $nbObservedAllNGrams->[0] * $nbObservedThisNGram->[1] / $nbObservedAllNGrams->[1];
	$self->{logger}->trace(" observed=".$nbObservedThisNGram->[0]." ; expected=$expected") if ($self->{debugMode});
	$self->{logger}->logconfess("expected value=0! Can not compute chi2") if ($expected==0);
	return ($nbObservedThisNGram->[0] - $expected)**2 / $expected;

}


=head2 requiresRefNGramsOnly()

see description in parent class

=cut

sub requiresRefNGramsOnly {
  return 1;
}


1;
