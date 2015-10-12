package Text::TextAnalytics::NGrams::HashByGramIndexedSequenceOfNGrams;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::HashByGramIndexedNGrams;
use Text::TextAnalytics::NGrams::SequenceOfNGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::HashByGramIndexedNGrams Text::TextAnalytics::NGrams::SequenceOfNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::HashByGramIndexedSequenceOfNGrams - Indexed NGrams collection,
implemented with a hash indexing "grams" and as a sequence of ngrams. 


=head1 DESCRIPTION

ISA = Text::TextAnalytics::NGrams::HashByGramIndexedNGrams Text::TextAnalytics::NGrams::SequenceOfNGrams

=cut


=head2 new($class, $params)

see superclass

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	$self->{ngramsKeys} = [];
	return $self; 
}


=head2 getNthNGram($index)

see superclass

=cut

sub getNthNGram {
	my $self = shift;
	my $index = shift;
	return $self->getNGramFromKey($self->getNthNGramKey($index));
	
}

=head2 getNthNGramKey($index)

see superclass

=cut

sub getNthNGramKey {
	my $self = shift;
	my $index = shift;
	return $self->{ngramsKeys}->[$index];
}


=head2 setNthNGram($ngram, $index)

see superclass

=cut

sub setNthNGram {
	my ($self, $ngram, $index) = @_;
	my $key = $self->getKey($ngram);
	$key = $self->createKey($ngram) if (!defined($key));
	return $self->setNthNGramFromKey($key, $index);
}

=head2 setNthNGramKey($key, $index)

see superclass

=cut

sub setNthNGramKey {
	my ($self, $key, $index) = @_;
	$self->{ngramsKeys}->[$index] = $key;
	return $key;
}


=head2 appendNGram($ngram)

see superclass

=cut

sub appendNGram {
	my ($self, $ngram) = @_;
	my $key = $self->getKey($ngram);
	$key = $self->createKey($ngram) if (!defined($key));
	return $self->appendNGramKey($key);
}

=head2 appendNGramKey($key)

see superclass

=cut

sub appendNGramKey {
	my ($self, $key) = @_;
	push(@{$self->{ngramsKeys}}, $key);
	return $key;
}


=head2 getKeysListRef()

see superclass

=cut

sub getKeysListRef {
	my $self=shift;
	return $self->{ngramsKeys};
}

=head2 getKeyValueIterator()

see superclass

=cut

sub getKeyValueIterator {
	my $self = shift;
	my $array = $self->{ngramsKeys};
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
	my @l = map {$self->getNGramFromKey($_)}  $self->{ngramsKeys};
	return \@l;
}

=head2 getTotalCount()

see superclass

=cut

sub getTotalCount {
	my $self = shift;
	return scalar(@{$self->{ngramsKeys}});
}


=head2 doForAllNGrams($toApplyToEveryLeafSub)

see superclass

=cut

sub doForAllNGrams {
	my ($self, $toApplyToEveryLeafSub) = @_;
	foreach my $key (@{$self->{ngramsKeys}}) {
		my $stop = $toApplyToEveryLeafSub->($self, $self->getNGramFromKey($key), 0, $key);
		return $stop if (!$stop);
	}
	return 1;
}


1;
