package Text::TextAnalytics::NGrams::CharsBagOfNGrams;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::BagOfNGrams;


our @ISA = qw/Text::TextAnalytics::NGrams::BagOfNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::CharsBagOfNGrams - Character NGrams collections (simple plain text hash keys without separator)

=head1 DESCRIPTION

ISA = Text::TextAnalytics::NGrams::BagOfNGrams

=head2 new($class, $params)

Mandatory parameter: $params->{n}

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	$self->{values} = {};
	$self->{nbIncCalls} = 0; 
	return $self; 
	
}

=head2 tokensAreCharacters()

returns true.

=cut

sub tokensAreCharacters {
	return 1;
}


=head2 getNbDistinctNGrams()

see superclass

=cut

sub getNbDistinctNGrams {
	my $self = shift;
	return scalar(keys %{$self->{values}});
}

=head2 getTotalCount()

see superclass

=cut

sub getTotalCount {
	my $self = shift;
	return $self->{nbIncCalls};
}


=head2 setTotalCount($value)

sets the total number of ngrams. warning: can lead to inconsistencies.

=cut

sub setTotalCount {
	my ($self, $value) = @_;
	$self->{nbIncCalls} = $value;
}


=head2 getKey($ngram)

see superclass

=cut

sub getKey {
	my ($self, $ngram) = @_;
	if (ref($ngram)) {
		$ngram = join("", @$ngram);
	}
	return $ngram;
}

  
=head2 getValue($ngram)

see superclass

ok for both $ngram as a ref list or as as a scalar. 
no check about size

=cut
sub getValue {
	my ($self, $ngram) = @_;
	if (ref($ngram)) {
		$ngram = join("", @$ngram);
	}
	return $self->{values}->{$ngram};
}

=head2 setValue($ngram, $value)

see superclass

=cut

sub setValue {
	my ($self, $ngram, $value) = @_;
	if (ref($ngram)) {
		$ngram = join("", @$ngram);
	}
	confess("Wrong number of grams") if (length($ngram) != $self->{n});
	$self->{values}->{$ngram} = $value;
	return $ngram;
}


=head2 incValue($ngram)

see superclass

=cut

sub incValue {
	my ($self, $ngram) = @_;
	if (ref($ngram)) {
		$ngram = join("", @$ngram);
	}
	confess("Wrong number of grams") if (length($ngram) != $self->{n});
	$self->{values}->{$ngram}++;
	$self->{nbIncCalls}++; 
	return $ngram;
}



=head2 getValueFromKey($key)

see superclass

=cut

sub getValueFromKey {
	return $_[0]->getValue($_[1]);
}


=head2 setValueFromKey($key, $value)

see superclass

=cut

sub setValueFromKey {
	my ($self, $ngram, $value) = @_;
	return $self->setValue($ngram, $value);
}


=head2 incValueFromKey($key)

see superclass

=cut

sub incValueFromKey {
	my ($self, $ngram) = @_;
	return $self->incValue($ngram);
}


=head2 getNGramFromKey($key)

see superclass

=cut

sub getNGramFromKey {
	my ($self, $key) = @_;
	my @chars;
	for(my $i=0;$i<length($key); $i++) {
		push(@chars, substr($key,$i,1));
	}
	return \@chars;
}

=head2 getNGramsListRef()

see superclass

=cut

sub getNGramsListRef {
	my $self = shift;
	my @ngrams;
	foreach my $ngram (keys %{$self->{values}}) {
		push(@ngrams, $self->getNGramFromKey($ngram));
	}
	return \@ngrams;
}


=head2 getKeysListRef()

see superclass

=cut

sub getKeysListRef {
	my $self = shift;
	my @ngrams = (keys %{$self->{values}});
	return \@ngrams;
}


=head2 getKeyValueIterator()

see superclass

=cut

sub getKeyValueIterator {
	my $self = shift;
	my $hash = $self->{values};
	keys %$hash; # reset hash for each().
	return sub { each(%$hash) };
}


sub removeNGram {
	my $self = shift;
	my $ngramKey = shift;
	$self->{nbIncCalls} -= $self->{value}->{$ngramKey};
	delete($self->{value}->{$ngramKey});
}


1; 
