package Text::TextAnalytics::Measure::Measure;

use strict;
use warnings;
use Carp;
use Log::Log4perl;

our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::Measure::Measure -  abstract class for similarity/distance measure

=cut



=head2 new($class, $parameters)

creates a new Measure object. no parameters.

this method should be called by subclasses constructors because it initializes the logger object $self->{logger},
in order not to spend time calling 	Log::Log4perl->get_logger(__PACKAGE__) in the frequently executed methods.
Additionally a boolean $self->{debugMode} is set in order to (possibly) optimize calls to the logger: instead of
using $self->{logger}->is_debug the method can test this variable, which is way faster. However using that disables
Log4perl mechanism about different categories (e.g. if the log config sets the DEBUG level for class X but not for this class
then nothing will be logged).


=cut

sub new {
	my ($class, $params) = @_;
	my $self;
	foreach my $opt (keys %$params) {
		$self->{$opt} = $params->{$opt};
	}
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);
	$self->{debugMode} = ($self->{logger}->is_debug)?1:0; # for efficiency
	$self->{logger}->info("debug mode is ".$self->{debugMode});
	bless($self, $class);
	return $self; 	
}


=head2 score($probeId, $probeData, $refId, $refData)

ABSTRACT

computes and returns the measure score between $data1 and $data2.
if the measure is directed, then as a convention it should compare $data1 (probe) against $data2 (reference)
$id1 and $id2 are identifiers: if defined, the measure can safely assume that the same id always corresponds to the same ngram. 
(useful not to compute norms twice, for example)

=cut



=head2 getName()

ABSTRACT

returns the name of the measure (some user-friendly short description)

=cut



=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = "";
	$str .=  $prefix."requiresSegmentsCountByNGram()=".$self->requiresSegmentsCountByNGram()."\n";
	$str .=  $prefix."isASimilarity()=".$self->isASimilarity()."\n";
	$str .=  $prefix."requiresOrderedNGrams()=".$self->requiresOrderedNGrams()."\n";
	$str .=  $prefix."requiresUniqueNGrams()=".$self->requiresUniqueNGrams()."\n";
	return $str;
}


=head2 requiresSegmentsCountByNGram()

ABSTRACT

returns true if the measure requires the count of segments by ngram (e.g. IDF)

=cut



=head2 setSegmentsCountByNGram($nbSegments, $segCount, $anyNGramReadForSharedIndex)

if the measure needs the segment counts data, it can process it here (this method is called before any call to score).
By default does nothing.

=cut 

sub setSegmentsCountByNGram {
}


=head2 getIDFVector()

ABSTRACT

This method does not have to be implemented if not relevant.
this a deprecated method from previous version.

=cut



=head2 isASimilarity()

ABSTRACT

return true if highest score means most similar for this measure

=cut




=head2 isADistance()

returns true if lowest score means most similar.
no need to be overriden (returns the opposite of isASimilarity()) 

=cut

sub isADistance {
	my $self = shift;
	return !$self->isASimilarity();
}

=head2 requiresOrderedNGrams() 

ABSTRACT

returns true if and only if this class works on ordered ngrams.
can return a ref to a list of two values, which means (ref, probe)

=cut

=head2 requiresUniqueNGrams() 

ABSTRACT

returns true if and only if this class works on unique ngrams.
can return a ref to a list of two values, which means (ref, probe)

=cut

=head2 checkNGramsObjects($refNGrams, $probeNGrams)

returns 1 if the ngrams objects are ok for the measure, 0 otherwise.
default: returns 1.

=cut
sub checkNGramsObjects {
	return 1;
}



1;
