package Text::TextAnalytics::Measure::Length;


use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::NGrams;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics::Measure::Measure;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::Measure/;


=head1 NAME

Text::TextAnalytics::Measure::Length - Module for "length distance"


=head1 DESCRIPTION

This "measure" actually only returns the length of the segment(s) (see options). useful as baseline or for some evaluation purposes.

ISA = Text::TextAnalytics::Measure::Measure

=cut

my %defaultOptions = (  
					   "average" => 1, 
					   "onlyProbe" => 0
					  ); 

my @parametersVars = (
						"average",
						"onlyProbe"
					 );



=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * average: true by default. if false, the sum of the lengths is returned instead of the average. (unused if onlyProbe is true)

=item * onlyProbe: return only the length of the probe segment; default is false

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
	return "Length";	
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

sub score { # this one is easy ;-)
	my ($self,$idProbe, $ngramsProbe, $idRef, $ngramsRef) = @_;
	return $ngramsProbe->getTotalCount() if ($self->{onlyProbe});
	my $score = $ngramsProbe->getTotalCount() + $ngramsRef->getTotalCount();
	$score /= 2 if ($self->{average});
	return $score;
}


1;
