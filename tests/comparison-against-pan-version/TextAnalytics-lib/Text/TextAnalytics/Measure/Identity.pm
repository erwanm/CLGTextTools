package Text::TextAnalytics::Measure::Identity;


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

Text::TextAnalytics::Measure::Identity - Module for simple binary same/different measure


=cut

=head1 DESCRIPTION

ISA = Text::TextAnalytics::Measure::Measure


=cut

my %defaultOptions = (  
					   "difference" => 0 
					  ); 

my @parametersVars = (
						"difference"
					 );



=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

=item * difference: assign 0 for identical ngrams and 1 for different (default is the contrary)

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
	return "Identity";	
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

depends on option difference

=cut


sub isASimilarity {
	my $self = shift;
	return !$self->{difference};	
}


=head2 score($probeId, $probeData, $refId, $refData)

see superclass

=cut

sub score {
	my ($self, $probeId, $probeNGram, $refId, $refNGram) = @_;

	$self->{logger}->logconfess("NGrams collections do not share the same index.") if (($probeNGram->isa($indexedNGramClassName)) && !$probeNGram->shareIndexWith($refNGram));
	
	return $self->{difference}?1:0 if ($probeNGram->getTotalCount() != $refNGram->getTotalCount()); # different length
	
	for (my $i=0; $i<$probeNGram->getTotalCount(); $i++) {
		return $self->{difference}?1:0 if ($probeNGram->getNthNGramKey($i) ne $refNGram->getNthNGramKey($i)); # different ngram found
	}
	return $self->{difference}?0:1; # no difference found
}

1;

