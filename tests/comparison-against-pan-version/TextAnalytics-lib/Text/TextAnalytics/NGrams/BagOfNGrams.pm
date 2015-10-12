package Text::TextAnalytics::NGrams::BagOfNGrams;

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Text::TextAnalytics::NGrams::NGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::NGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::BagOfNGrams - Abstract class for bags of NGrams

=cut



=head2 setTotalCount($value)

ABSTRACT

sets the total number of ngrams. warning: can lead to inconsistencies.

=cut



=head2 getNbDistinctNGrams()

ABSTRACT

returns the number of distinct ngrams in this collection.

=cut




=head2 ngramsAreOrdered()

returns false.
 
=cut

sub ngramsAreOrdered {
	return 0;
}

=head2 ngramsAreUnique()

returns true.
 
=cut

sub ngramsAreUnique {
	return 1;
}




=head2 getValue($ngram)

ABSTRACT

returns the value for this ngram
returns undef in the following cases:

=over 2

=item * the n-gram does not exist in the index

=item * the n-gram value is undef 

=back

=cut



=head2 getValueFromKey($key)

ABSTRACT

obtain value using the ngram "key", i.e. using the internal representation of the ngram

=cut



=head2 setValue($ngram, $value)

ABSTRACT

returns the key or ngram (as a scalar)

=cut



=head2 setValueFromKey($key, $value)

ABSTRACT

set value using the ngram "key", i.e. using the internal representation of the ngram
returns the ngram key.

returns undef if no such key or key is undefined.

=cut



=head2 incValue($ngram)

ABSTRACT

returns the ngram key

=cut



=head2 incValueFromKey($key)

ABSTRACT

increments value using the ngram "key", i.e. using the internal representation of the ngram

=cut



=head2 addNGram($ngram)

returns $self->incValue($ngram);

=cut

sub addNGram {
	my ($self, $ngram) = @_;
	return $self->incValue($ngram);
}


=head2 addNGramFromKey($key)

returns $self->incValueFromKey($key)

=cut

sub addNGramFromKey {
	my ($self, $key) = @_;
	return $self->incValueFromKey($key);
}



=head2 valuesAsShortString($idfVector)

returns a string representation of the ngrams collection, where the ngrams are sorted by key
and each ngram is written key-ngram[-IDF].
$idfVector is an optional parameter.

=cut

sub valuesAsShortString {
	my $self = shift;
	my $idfVector = shift; # optional

	my $res="";
	my $possiblyIDF="";
	foreach my $key (sort {$self->getValueFromKey($b) <=> $self->getValueFromKey($a)}  @{$self->getKeysListRef()}) {
		if (defined($idfVector)) {
			$possiblyIDF = defined($idfVector->{$key})?("-".$idfVector->{$key}):"_";
		}
		$res .= " $key-".$self->getValueFromKey($key).$possiblyIDF;
	}
	return $res;
}


=head2 valuesAsShortStringWithDetails($idfVector)

see valuesAsShortString (returns this string preceded by "(N,M)", where N is the number
of distinct ngrams and M the total number of ngrams)

=cut

sub valuesAsShortStringWithDetails {
	my $self = shift;
	my $idfVector = shift; # optional

	return "(".$self->getNbDistinctNGrams().";".$self->getTotalCount().")".$self->valuesAsShortString($idfVector);

}


=head2 filterOutRareNGrams($threshold)

set the value to 0 for ngrams for which value is lower than $threshold.  

=cut

sub filterOutRareNGrams {
	my $self= shift;
	my $threshold = shift;
	my $nextKeyValue = $self->getKeyValueIterator();
	while (my @keyValuePair = $nextKeyValue->()) {
		$self->removeNGram($keyValuePair[0]) if ($keyValuePair[1] < $threshold);
#		 if ($self->{debugMode}); 
	}
}

=head2 removeNGram($ngramKey)

ABSTRACT

note: does not modify totalCount

=cut


1;
