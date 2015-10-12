package Text::TextAnalytics::NGrams::SimpleNGrams;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::BagOfNGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::BagOfNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::SimpleNGrams - NGrams collections, simple approach (plain text hash keys)


=cut

=head1 DESCRIPTION

ISA = Text::TextAnalytics::NGrams::BagOfNGrams
=cut

my %defaultOptions = ( "separator" => " " );

=head2 new($class, $params)

creates a new collection of $N-grams. 
Mandatory parameter: $params->{n}.
Optional parameter: $params->{separator}.
if $separator is provided it will be used between "grams", e.g. ( 'an', 'example' ) -> "an${separator}example"

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{values} = {};
	$self->{nbIncCalls} = 0; 
	return $self; 
	
}


=head2 tokensAreCharacters()

returns false.

=cut

sub tokensAreCharacters {
	return 0;
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




=head2 setTotalCount($value)

sets the total number of ngrams. warning: can lead to inconsistencies.

=cut

sub setTotalCount {
	my ($self, $value) = @_;
	$self->{nbIncCalls} = $value;
}

 
=head2 getValue($ngram)

see superclass.
$ngram as a ref list as well as a scalar with separator (or unigram of course). nothing checked in the latter case.

=cut

sub getValue {
	my ($self, $ngram) = @_;
	if (ref($ngram)) {
		croak("Wrong number of grams") if (scalar(@$ngram) != $self->{n});
		$ngram = join($self->{separator}, @$ngram);
	}
	return $self->{values}->{$ngram};
}



=head2 setValue($ngram, $value)

see superclass

=cut

sub setValue {
	my ($self, $ngram, $value) = @_;
	if (ref($ngram)) {
		croak("Wrong number of grams") if (scalar(@$ngram) != $self->{n});
		$ngram = join($self->{separator}, @$ngram);
	}
	$self->{values}->{$ngram} = $value;
	return $ngram;
}




=head2 incValue($ngram)

see superclass

=cut

sub incValue {
	my ($self, $ngram) = @_;
	if (ref($ngram)) {
		croak("Wrong number of grams") if (scalar(@$ngram) != $self->{n});
		$ngram = join($self->{separator}, @$ngram);
	}
	$self->{values}->{$ngram}++;
	$self->{nbIncCalls}++;
	return $ngram; 
}

=head2 getKey($ngram)

see superclass

=cut

sub getKey {
	my ($self, $ngram) = @_;
	return join($self->{separator}, @$ngram);
}



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



=head2 getNGramFromKey($key)

see superclass

=cut

sub getNGramFromKey {
	my ($self, $key) = @_;
	my  @ngram = split(/$self->{separator}/, $key);
	return \@ngram;
}



=head2 getValueFromKey($key)

see superclass

=cut

sub getValueFromKey {
	my ($self, $key) = @_;
	return $self->getValue($key);
}

=head2 setValueFromKey($key, $value)

see superclass

=cut

sub setValueFromKey {
	my ($self, $key, $value) = @_;
	return $self->setValue($key, $value);
}


=head2 incValueFromKey($key)

see superclass

=cut

sub incValueFromKey {
	my ($self, $key) = @_;
	return $self->incValue($key);
}


=head2 getNGramsListRef()

see superclass

=cut

sub getNGramsListRef {
	my $self = shift;
	my @ngrams;
	foreach (keys %{$self->{values}}) {
		my @ngram = split(/$self->{separator}/);
		push(@ngrams, \@ngram);
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


1;
