package Text::TextAnalytics::NGrams::CharsSequenceOfNGrams;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::SequenceOfNGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::SequenceOfNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::CharsSequenceOfNGrams - Character NGrams collections (simple plain text hash keys without separator)


=head1 DESCRIPTION

ISA = Text::TextAnalytics::NGrams::SequenceOfNGrams

=cut


=head2 new($class, $params)

see superclass

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	$self->{ngrams} = [];
	return $self; 
}


=head2 tokensAreCharacters()

returns true.

=cut

sub tokensAreCharacters {
	return 1;
}

=head2 getKey($ngram)

see superclass

=cut

sub getKey {
	my ($self, $ngram) = @_;
	return $ngram;
}



=head2 getNthNGram($index)

see superclass

=cut

sub getNthNGram {
	my $self = shift;
	my $index = shift;
	return $self->getNthNGramKey($index);
}

=head2 getNthNGramKey($index)

see superclass

=cut

sub getNthNGramKey {
	my $self = shift;
	my $index = shift;
	return $self->{ngrams}->[$index];
}


=head2 setNthNGram($ngram, $index)

see superclass

=cut

sub setNthNGram {
	my ($self, $ngram, $index) = @_;
	return $self->setNthNGramFromKey($ngram, $index);
}

=head2 setNthNGramKey($key, $index)

see superclass

=cut

sub setNthNGramKey {
	my ($self, $key, $index) = @_;
	$self->{ngrams}->[$index] = $key;
	return $key;
}


=head2 appendNGram($ngram)

see superclass

=cut

sub appendNGram {
	my ($self, $ngram) = @_;
	return $self->appendNGramKey($ngram);
}

=head2 appendNGramKey($key)

see superclass

=cut

sub appendNGramKey {
	my ($self, $key) = @_;
	push(@{$self->{ngrams}}, $key);
	return $key;
}


=head2 getKeysListRef()

see superclass

=cut

sub getKeysListRef {
	my $self=shift;
	return $self->{ngrams};
}

=head2 getKeyValueIterator()

see superclass

=cut

sub getKeyValueIterator {
	my $self = shift;
	my $array = $self->{ngrams};
	my $i=0;
	return sub { 
		if ($i < scalar(@$array)) {
			return ($i, $array->[$i]);
		 } else {
		 	return ();
		 };
	}
}



=head2 getNGramsListRef()

see superclass

=cut

sub getNGramsListRef {
	my $self = shift;
	return $self->getKeysListRef();
}

=head2 getTotalCount()

see superclass

=cut

sub getTotalCount {
	my $self = shift;
	return scalar(@{$self->{ngrams}});
}



=head2 doForAllNGrams($toApplyToEveryLeafSub)

see superclass

=cut

sub doForAllNGrams {
	my ($self, $toApplyToEveryLeafSub) = @_;
	foreach my $key (@{$self->{ngrams}}) {
		my $stop = $toApplyToEveryLeafSub->($self, $key, 0, $key);
		return $stop if (!$stop);
	}
	return 1;
}


1;
