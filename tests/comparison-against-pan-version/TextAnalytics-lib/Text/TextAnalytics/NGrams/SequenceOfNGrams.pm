package Text::TextAnalytics::NGrams::SequenceOfNGrams;

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Text::TextAnalytics::NGrams::NGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::NGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::SequenceOfNGrams - Abstract class for sequences of NGrams

=cut




=head2 ngramsAreOrdered()

returns true.
 
=cut

sub ngramsAreOrdered {
	return 1;
}

=head2 ngramsAreUnique()

returns false.
 
=cut

sub ngramsAreUnique {
	return 0;
}


=head2 addNGram($ngram)

see superclass

=cut

sub addNGram {
	my $self = shift;
	my $ngram = shift;
	$self->appendNGram($ngram);
}

=head2 addNGramFromKey($key)

see superclass

=cut

sub addNGramFromKey {
	my $self = shift;
	my $key = shift;
	$self->appendNGramKey($key);
}



=head2 getNthNGram($index)

ABSTRACT

returns the $index-th ngram of the sequence.
Warning: indexes usually start at 0 (so that this is actually the ($index+1)th ngram)

=cut


=head2 getNthNGramKey($index)

ABSTRACT

returns the key for the $index th ngram of the sequence.
Warning: indexes usually start at 0 (so that this is actually the ($index+1)th ngram)

=cut



=head2 setNthNGram($ngram, $index)

ABSTRACT

sets the $index-th ngram of the sequence.
Warning: indexes usually start at 0 (so that this is actually the ($index+1)th ngram)

=cut


=head2 setNthNGramKey($key, $index)

ABSTRACT

sets the key for the $index-th ngram of the sequence.
Warning: indexes usually start at 0 (so that this is actually the ($index+1)th ngram)

=cut

=head2 appendNGram($ngram)

ABSTRACT

adds the key corresponding to $ngram at the end of the sequence (the key is created if needed)

=cut

=head2 appendNGramKey($key)

ABSTRACT

adds $key at the end of the sequence (the key must already exist). 

=cut



=head2 valuesAsShortString($idfVector)

ABSTRACT 

returns a string representation of the ngrams collection, depends on the class.
$idfVector is an optional parameter.

=cut

sub valuesAsShortString {
	my $self = shift;
	my $idfVector = shift; # optional

	my $res="";
	my $possiblyIDF="";
	foreach my $key (@{$self->getKeysListRef()}) {
		if (defined($idfVector)) {
			$possiblyIDF = defined($idfVector->{$key})?("-".$idfVector->{$key}):"_";
		}
		$res .= " $key".$possiblyIDF;
	}
	return $res;
}


1;
