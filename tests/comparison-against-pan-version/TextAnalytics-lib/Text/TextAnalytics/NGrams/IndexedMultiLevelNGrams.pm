package Text::TextAnalytics::NGrams::IndexedMultiLevelNGrams;
        
use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::MultiLevelNGrams;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics qw/genericObjectBuilder/;
use Scalar::Util 'blessed';


our @ISA = qw/Text::TextAnalytics::NGrams::MultiLevelNGrams Text::TextAnalytics::NGrams::IndexedNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::NGrams::IndexedMultiLevelNGrams - class for collections containing several collections of indexed ngrams

ISA = Text::TextAnalytics::NGrams::IndexedNGrams Text::TextAnalytics::NGrams::MultiLevelNGrams

=cut


=head1 DESCRIPTION

=cut

my %defaultOptions = (  
					   "nGramsClassName" => "HashByGramIndexedBagOfNGrams" 
					  ); 

my @parametersVars = (
					   "nGramsClassName" 
					 );





=head2 new

parameters: shared, nGramsClassName, nGramsParams

must be called by subclasses

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params); # MultiLevelNGrams new
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{nGramsParams} = {} if (!defined($self->{nGramsParams}));
	my $logger = $self->{logger};
	if (scalar(@{$self->{levelLength}}) > 0) {
		my $dummyNGram = genericObjectBuilder($self->{nGramsClassName}, { n => $self->{levelLength}->[0], shared => $self->{shared}, %{$self->{nGramsParams}} }, $Text::TextAnalytics::prefixModuleNGrams); 
		$self->{shared} = $dummyNGram if (!defined($self->{shared}));
		for (my $levelNo = 0; $levelNo < scalar(@{$self->{levelLength}}); $levelNo++) {
			$self->{levelNGrams}->[$levelNo] = genericObjectBuilder($self->{nGramsClassName}, { n => $self->{levelLength}->[$levelNo], shared => $self->{shared}, %{$self->{nGramsParams}} }, $Text::TextAnalytics::prefixModuleNGrams); 
		}
	} else {
		$logger->logwarn("Warning: no levels at all in IndexedMultiLevelNGrams.");
	} 
	return $self; 
}


# TODO dirty

sub getSharedData {
	my $self = shift;
	return $self->{levelNGrams}->[0];
}


#
# TODO VERY VERY DIRTY
#
sub returnKeyFromList {
	my ($self, $l) = @_;
	return $self->{levelNGrams}->[0]->returnKeyFromList($l);
}



=head2 getIndexedNGramsLevel($level)

=cut

sub getIndexedNGramsLevel {
	my $self = shift;
	my $level = shift;
	return $self->{levelNGrams}->[$level];
}


=head2 shareIndexWith($otherIndexedNGrams)

returns true if 1) the class can deal with shared indexes and 2) the current object and $otherIndexedNGrams share the same index

=cut

sub shareIndexWith {
	my ($self, $otherNGram) = @_;
	$self->{logger}->logconfess("Invalid reference object to shared index (object is not blessed)") unless (blessed($otherNGram));
#	$self->{logger}->logconfess("Invalid reference object to shared index (object is not a ".__PACKAGE__.")") unless ($otherNGram->isa(__PACKAGE__));
	return $otherNGram->shareIndexWith($self->{levelNGrams}->[0]);
#	return ($self->{levelNGrams}->[0]->shareIndexWith($otherNGram));
}



=head2 addNgramLevel($ngram, $level)

see superclass

=cut

sub addNGramLevel {
	my ($self, $ngram, $levelNo) = @_;
	$self->{logger}->debug("adding ngram [ ".join(" ; ",@$ngram)." ] for level $levelNo") if ($self->{debugMode});
	return $self->{levelNGrams}->[$levelNo]->addNGram($ngram);
}



=head2 createKeyLevel($ngram, $level)

creates a new key for $ngram in the index. Warning: does not necessarily check if the ngram is already indexed.

=cut

sub createKeyLevel {
	my ($self, $ngram, $levelNo) = @_;
	return $self->{levelNGrams}->[$levelNo]->createKey($ngram);
}


=head2 createKey($ngram)

error multiLevel

=cut

sub createKey {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use createKeyLevel instead.");
}



=head2 getSharedKeysListRefLevel($level)

see superclass

=cut

sub getSharedKeysListRefLevel {
	my ($self, $levelNo) = @_;
	return $self->{levelNGrams}->[$levelNo]->getSharedKeysListRef();
}


=head2 getSharedKeysListRef()

error multiLevel

=cut

sub getSharedKeysListRef {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getSharedKeysListRefLevel instead.");
}




=head2 tokensAreCharacters()

see superclass

=cut

sub tokensAreCharacters {
	my $self = shift;
	return $self->{levelNGrams}->[0]->tokensAreCharacters();
}




=head2 getTotalCountLevel($level)

see superclass

=cut

sub getTotalCountLevel {
	my $self = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getTotalCount();
}




=head2 addNGramFromKeyLevel($key, $level)

see superclass

=cut

sub addNGramFromKeyLevel {
	my $self = shift;
	my $key = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->addNGramFromKey($key);
}


=head2 getNGramFromKeyLevel($key, $level)

see superclass

=cut

sub getNGramFromKeyLevel {
	my $self = shift;
	my $key = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getNGramFromKey($key);
}


=head2 getKeyLevel($ngram, $level)

see superclass

=cut

sub getKeyLevel {
	my $self = shift;
	my $ngram = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getKey($ngram);
}


=head2 	getNGramsListRefLevel($level)

see superclass

=cut

sub getNGramsListRefLevel {
	my $self = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getNGramsListRef();
}



=head2 getKeysListRefLevel($level)

see superclass

=cut

sub getKeysListRefLevel {
	my $self = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getKeysListRef();
}



=head2 setTotalCountLevel($value, $level)

see superclass

=cut

sub setTotalCountLevel {
	my $self = shift;
	my $value = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->setTotalCount($value);
}


=head2 getNbDistinctNGramsLevel($level)

see superclass

=cut

sub getNbDistinctNGramsLevel {
	my $self = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getNbDistinctNGrams();
}


=head2 getValueLevel($ngram, $level)

see superclass

=cut

sub getValueLevel {
	my $self = shift;
	my $ngram = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getValue($ngram);
}


=head2 getValueFromKeyLevel($key, $level)

see superclass

=cut

sub getValueFromKeyLevel {
	my $self = shift;
	my $key = shift;
	my $levelNo = shift;
	$self->{logger}->debug("looking for key $key at level $levelNo") if ($self->{debugMode});
	return $self->{levelNGrams}->[$levelNo]->getValueFromKey($key);
}



=head2 setValueLevel($ngram, $value, $level)

see superclass

=cut

sub setValueLevel {
	my $self = shift;
	my $ngram = shift;
	my $value = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->setValue($ngram, $value);
}


=head2 setValueFromKeyLevel($key, $value, $level)

see superclass

=cut

sub setValueFromKeyLevel {
	my $self = shift;
	my $key = shift;
	my $value = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->setValueFromKey($key, $value);
}


=head2 incValueLevel($ngram, $level)

see superclass

=cut

sub incValueLevel {
	my $self = shift;
	my $ngram = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->incValue($ngram);
}


=head2 incValueFromKeyLevel($key, $level)

see superclass

=cut

sub incValueFromKeyLevel {
	my $self = shift;
	my $key = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->incValueFromKey($key);
}


=head2 getKeyValueIteratorLevel($level)

see superclass

=cut


sub getKeyValueIteratorLevel {
	my $self = shift;
	my $levelNo = shift;
	return $self->{levelNGrams}->[$levelNo]->getKeyValueIterator();
}




1;
