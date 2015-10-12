package Text::TextAnalytics::Measure::Okapi;


use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::NGrams;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics::Measure::CosineTFIDF;
use Text::TextAnalytics qw/readNGramsFile/;
use Text::TextAnalytics qw/$indexedNGramClassName/;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::Measure::CosineTFIDF/;


=head1 NAME

Text::TextAnalytics::Measure::Okapi - Module for Okapi measure


=cut

=head1 DESCRIPTION

ISA = Text::TextAnalytics::Measure::CosineTFIDF

=cut

my %defaultOptions = (  
					  ); 

my @parametersVars = (
						"avgLength",
						"noIDF",
						"storeNorms",
						"loadSegmentCountFromFile",
						"segmentCountFilecontainsKeys"
					 );

our $defaultIDFPenaltyKeyName = "DEFAULT_IDF_PENALTY";

our $k1Constant = 2;
our $bConstant = 0.75;

# TODO

=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:

=over 2

TODO 

avgLength

=item * storeNorms: boolean, wether or not to store vector norm (if there is an identifier) in order not to compute it again later.

=item * loadSegmentCountFromFile: if defined, filename of the file from which the segments counts should be read (format: as written by CountNGramsOnlyHLComparator)

=item * segmentCountFilecontainsKeys: if loadSegmentCountFromFile is defined, indicates whether the format includes ngrams keys (default false).

WARNING: if storeNorms is set, the ids must be unique (including between probe/ref!)

=back

=cut


sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{logger}->logconfess("Parameter avgLength must be defined.") if (!defined($self->{avgLength}));
	return $self;
}


=head2 getName()

see superclass

=cut

sub getName() {
	return "Okapi";	
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


sub computeTFIDFWeight {
	my ($self, $total, $ngrams, $key) = @_;
	my $count = $ngrams->getValueFromKey($key);
	my $idf = $self->{idfVector}->{$key};
	$idf = $self->{idfVector}->{$defaultIDFPenaltyKeyName} if (!defined($idf));
	$self->{logger}->logconfess("No IDF value for ngram id '$key' and no default idf penalty (key $defaultIDFPenaltyKeyName) provided") if (!defined($idf));
	my $weight = ($count * $k1Constant +1) / ($count + $k1Constant * ( 1 - $bConstant + ($bConstant * $total / $self->{avgLength} ) ) ) * $idf;
	$self->{logger}->trace("ngram id '$key': count=$count; totalCount=".$ngrams->getTotalCount()."; IDF=$idf, TF.IDF=$weight") if ($self->{debugMode});
	return $weight;
}

sub computeIDF {
	my ($self, $docCount, $docTotal) = @_;
#	print STDERR "DEBUG docCount=$docCount docTotal=$docTotal\n";
	return log( ( $docTotal - $docCount + 0.5 ) / ( $docCount + 0.5 ) ); ## compute IDF
}


1;
