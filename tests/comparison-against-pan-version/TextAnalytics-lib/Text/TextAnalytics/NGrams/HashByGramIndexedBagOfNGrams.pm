package Text::TextAnalytics::NGrams::HashByGramIndexedBagOfNGrams;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::HashByGramIndexedNGrams;
use Text::TextAnalytics::NGrams::BagOfNGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::HashByGramIndexedNGrams Text::TextAnalytics::NGrams::BagOfNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::HashByGramIndexedBagOfNGrams - Indexed NGrams collection,
implemented with a hash indexing "grams" and as a bag of ngrams. 


=head1 DESCRIPTION

ISA = Text::TextAnalytics::NGrams::HashByGramIndexedNGrams Text::TextAnalytics::NGrams::BagOfNGrams

=cut


=head2 new($class, $params)

see superclass

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	$self->{value} = {};
	$self->{nbIncValueCalls} = 0;
	return $self; 
}

=head2 getNbDistinctNGrams()

see superclass

=cut

sub getNbDistinctNGrams {
	my ($self) = @_;
	return scalar(keys %{$self->{value}});
}

=head2 getValueFromKey($index)

see superclass

=cut

sub getValueFromKey {
	my ($self, $i) = @_;
	if (!defined $i) {
		return undef;
	}
	return $self->{value}->{$i};
}

=head2 getValue($ngram)

see superclass

=cut

sub getValue {
	my $self = shift;
	my $ngram = shift;
	if ($self->{debugMode}) {
		my $key =$self->getKey($ngram);
		$self->{logger}->debug("getValue for ".(ref($ngram)?join("|", @$ngram):$ngram)." -> key is ".(defined($key)?$key:"undefined"));
	}
	return $self->getValueFromKey($self->getKey($ngram));
}



=head2 setValueFromKey($key, $value)

see superclass. no check about index validity (must only be defined)

=cut

sub setValueFromKey {
	my ($self, $key, $value) = @_;
	if (!defined($key)) {
		$self->{logger}->logconfess("Error: undefined key.");
	}  
	$self->{value}->{$key} = $value;
	return $key;
}


=head2 setValue($ngram, $value)

see superclass 

=cut

sub setValue {
	my $self = shift;
	my $ngram = shift;
	my $value = shift;
	my $index = $self->getKey($ngram);
	if (!defined $index) {
		$index = $self->createKey($ngram);
	}
	$self->setValueFromKey($index, $value);
	return $index;
}


=head2 incValue($value, $ngram)

see superclass 

=cut

sub incValue {
	my $self = shift;
	my $ngram = shift;
	my $index = $self->getKey($ngram);
	if (!defined $index) {
		$index = $self->createKey($ngram);
	}
	$self->{value}->{$index}++;
	$self->{nbIncValueCalls}++;
	return $index;
}


=head2 incValueFromKey($value, $key)

see superclass 

=cut

sub incValueFromKey {
	my $self = shift;
	my $key = shift;
	$self->{value}->{$key}++;
	$self->{nbIncValueCalls}++;
	return $key;
}

=head2 getKeysListRef()

see superclass

=cut

sub getKeysListRef {
	my $self=shift;
	my @l =  keys %{$self->{value}};
	return \@l;
}

=head2 getKeyValueIterator()

see superclass

=cut

sub getKeyValueIterator {
	my $self = shift;
	my $hash = $self->{value};
	keys %$hash; # reset hash for each().
	return sub { return each(%$hash); };
}

=head2 getNGramsListRef()

see superclass

=cut

sub getNGramsListRef {
	my ($self) = @_;
	my @l;
	foreach my $index (keys %{$self->{value}}) {
		push(@l, $self->getNGramFromKey($index));
	}
	return \@l;
}

=head2 getTotalCount()

see superclass

=cut

sub getTotalCount {
	my $self = shift;
	return $self->{nbIncValueCalls};
}


=head2 setTotalCount($value)

sets the total number of ngrams. warning: can lead to inconsistencies.

=cut

sub setTotalCount {
	my ($self, $value) = @_;
	$self->{nbIncValueCalls} = $value;
}


=head2 doForAllNGrams($toApplyToEveryLeafSub)

see superclass

=cut

sub doForAllNGrams {
	my ($self, $toApplyToEveryLeafSub) = @_;
	foreach my $index (keys %{$self->{value}}) {
		my $stop = $toApplyToEveryLeafSub->($self, $self->getNGramFromKey($index), $self->getValueFromKey($index), $index);
		return $stop if (!$stop);
	}
	return 1;
}


=head2 removeNGram($ngramKey)


=cut

sub removeNGram {
	my $self = shift;
	my $ngramKey = shift;
	$self->{nbIncValueCalls} -= $self->{value}->{$ngramKey};
	delete($self->{value}->{$ngramKey});
}

1;
