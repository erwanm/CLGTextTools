package Text::TextAnalytics::NGrams::MultiLevelNGrams;
        
use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::BagOfNGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::BagOfNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::NGrams::MultiLevelNGrams - abstract class for collections containing several collections of ngrams

ISA = Text::TextAnalytics::NGrams::BagOfNGrams

=cut


=head1 DESCRIPTION

=cut





=head2 new

parameters: N as a string of the form <level1>,<level2>,...
where <level-i> is either a number or a sequence of Y or N
e.g. "1,2,3" means using levels unigram, bigram, trigram
"1,2,YNY" means unigram, bigram and skip-grams based on sequences of length 2 containg the first and last token.

must be called by subclasses

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	my $logger = $self->{logger};
	$self->{n} = uc($self->{n});
	my $levelNo=0;
		$logger->debug("init MultiLevelNGrams, n='".$self->{n}."'") if ($self->{debugMode});
	for my $levelStr (split(/,/, $self->{n})) {
		$logger->debug("init level $levelNo with '$levelStr'") if ($self->{debugMode});
		if ($levelStr =~ m/^\d+$/) {
			$self->{levelLength}->[$levelNo] = $levelStr;
		} elsif ($levelStr =~ m/^[YN]+$/) {
			my @pattern;
			my $length=0;
			for (my $i = 0; $i < length($levelStr); $i++) {
				$pattern[$i]=(substr($levelStr,$i,1) eq "Y")?1:0;
				$length++ if (substr($levelStr,$i,1) eq "Y");
			}
			$self->{levelLength}->[$levelNo] = $length;
			$self->{levelPattern}->{$levelNo} = \@pattern;
		} else {
			$logger->logconfess("Invalid level pattern for MultiLevelNgram: '$levelStr' (must be either a number or a sequence of Y/N characters)");
		}
		$levelNo++;
	}
	$logger->logconfess("At least one level must be specified in MultiLevelNGrams (n=".$self->{n}.")") if (!defined($self->{levelLength}));
	return $self; 
}


=head2 getNbLevels()

=cut

sub getNbLevels {
	my $self = shift;
	return scalar(@{$self->{levelLength}});
}

=head2 getLength($level)
 
=cut
 
sub getLength  {
	my $self = shift;
	my $level = shift;
	return $self->{levelLength}->[$level];
}



=head2 getPattern($level)
 
=cut
 
sub getPattern  {
	my $self = shift;
	my $level = shift;
	return $self->{levelPattern}->{$level};
}
 
 

=head2 getTotalCountLevel($level)

ABSTRACT

returns the total number of ngrams. warning: only ngrams which have been added using addTokens/addNGram are taken into account.

=cut

=head2 getTotalCount()

error multiLevel

=cut

sub getTotalCount {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getTotalCountLevel instead.");
}


=head2 addNgramLevel($ngram, $level)

ABSTRACT

add $ngram to the ngram collection only at level $level.

=cut

=head2 addNGram($ngram)

error multiLevel

=cut

sub addNGram {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use addNGramLevel instead.");
}


=head2 addNGramFromKeyLevel($key, $level)

ABSTRACT

adds the ngram defined by this key using the default method (depending on the class).

=cut

=head2 addNGramFromKey($key)

error multiLevel

=cut

sub addNGramFromKey {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use addNGramFromKeyLevel instead.");
}


=head2 getNGramFromKeyLevel($key, $level)

ABSTRACT

usually very unefficient, use only for small objects or for debuging purpose

=cut

=head2 getNGramFromKey($key)

error multiLevel

=cut

sub getNGramFromKey {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getNGramFromKeyLevel instead.");
}


=head2 getKeyLevel($ngram, $level)

ABSTRACT

returns the internal representation of the given ngram. returns undef if ngram does not exist.

=cut

=head2 getKey($ngram)

error multiLevel

=cut

sub getKey {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getKeyLevel instead.");
}



=head2 	getNGramsListRefLevel($level)

ABSTRACT

returns the list (as a ref) of of all ngrams possibly contained in the structure (i.e. all ngrams contained are in the list but the list can contain more ngrams)
important: the ngrams in this list are expected to be provided as lists refs, and are supposed to be usable as a parameter with getKey

=cut

=head2 	getNGramsListRef()

error multiLevel

=cut

sub getNGramsListRef {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getNGramsListRefLevel instead.");
}




=head2 getKeysListRefLevel($level)

ABSTRACT

returns a ref to a list of ngrams keys which internally represent the ngrams. must be usable with getNGramsFromKey

=cut

=head2 getKeysListRef()

error multiLevel

=cut

sub getKeysListRef {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getKeysListRefLevel instead.");
}



# TODO doForAllNGrams, prettyPrint etc.



=head2 setTotalCountLevel($value, $level)

ABSTRACT

sets the total number of ngrams. warning: can lead to inconsistencies.

=cut

=head2 setTotalCount($value)

error multiLevel

=cut

sub setTotalCount {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use setTotalCountLevel instead.");
}


=head2 getNbDistinctNGramsLevel($level)

ABSTRACT

returns the number of distinct ngrams in this collection.

=cut


=head2 getNbDistinctNGrams()

error multiLevel

=cut

sub getNbDistinctNGrams {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getNbDistinctNGramsLevel instead.");
}


=head2 getValueLevel($ngram, $level)

ABSTRACT

returns the value for this ngram
returns undef in the following cases:

=over 2

=item * the n-gram does not exist in the index

=item * the n-gram value is undef 

=back

=cut

=head2 getValue($ngram)

error multiLevel

=cut

sub getValue {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getValueLevel instead.");
}


=head2 getValueFromKeyLevel($key, $level)

ABSTRACT

obtain value using the ngram "key", i.e. using the internal representation of the ngram

=cut

=head2 getValueFromKey($key)

error multiLevel

=cut

sub getValueFromKey {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use getValueFromKeyLevel instead.");
}



=head2 setValueLevel($ngram, $value, $level)

ABSTRACT

returns the key or ngram (as a scalar)

=cut

=head2 setValue($ngram, $value)

error multiLevel

=cut

sub setValue {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use setValueLevel instead.");
}


=head2 setValueFromKeyLevel($key, $value, $level)

ABSTRACT

set value using the ngram "key", i.e. using the internal representation of the ngram
returns the ngram key.

returns undef if no such key or key is undefined.

=cut

=head2 setValueFromKey($key, $value)

error multiLevel

=cut

sub setValueFromKey {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use setValueFromKeyLevel instead.");
}



=head2 incValueLevel($ngram, $level)

ABSTRACT

returns the ngram key

=cut


=head2 incValue($ngram)

error multiLevel

=cut

sub incValue {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use incValueLevel instead.");
}



=head2 incValueFromKeyLevel($key, $level)

ABSTRACT

increments value using the ngram "key", i.e. using the internal representation of the ngram

=cut

=head2 incValueFromKey($key)

error multiLevel

=cut

sub incValueFromKey {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use incValueFromKeyLevel instead.");
}



=head2 addNGramFromKeyLevel($key, $level)

returns $self->incValueFromKey($key, $level)

=cut

sub addNGramFromKeyLevel {
	my ($self, $key, $level) = @_;
	return $self->incValueFromKey($key, $level);
}








=head2 addTokens($tokens, $distinctNGramsHashRef, $minNGrams)

adds a set/sequence of tokens to the object.
if the second (optional) parameter is provided, $distinctNGramsHashRef->[$levelNo]->{id(X)} will be incremented for every distinct ngram X in $listRef (useful for IDF)
if the 3rd parameter $minNGrams is provided, then the tokens are added only of the total number of ngrams to add is at least $minNGrams.

####returns an array containing the number of ngrams actually added for every level, or -1 if $minNGrams was provided and the condition was not satisfied. 
returns the total number of ngrams added (all levels), or -1 if $minNGrams was provided and the condition was NEVER satisfied (for any level).
note that a return value of 0 or -1 
means the same for this method, the difference is only provided in order to inform the caller of the (first) reason why no ngrams were added. In other words
the caller can test if return value > 0 if the goal is to know if any ngram was added, or if return value > 0 if the goal is to know whether the segment was skipped. 

update: can take as input both a list ref or a string (in which case ngrams are characters)

see also ngramsAreOrdered(), ngramsAreUnique().

=cut

sub addTokens {
	my ($self, $tokens, $distinctNGramsHashRef, $minNGrams) = @_;
	my $logger = $self->{logger};
	my $nbNGrams = 0;
#	print "DEBUGGGG ".$tokens->[0]." ".$tokens->[1]." ".$tokens->[2]."\n";
	my $atLeastOneLevelWithoutMinCondition = 0;
#	my $n = $self->getN();
	my $tokensAsListRef = (ref($tokens) eq "ARRAY");
	$logger->debug("Nb levels=".scalar(@{$self->{levelLength}})) if ($self->{debugMode});
	for (my $levelNo = 0; $levelNo < scalar(@{$self->{levelLength}}); $levelNo++) {
		my %distinctNGramsInThis;
		my $levelLength  =$self->{levelLength}->[$levelNo];
		my $extendedSizeLevel = $self->getLevelExtendedSize($levelNo);
		$logger->debug("adding tokens for level $levelNo: levelLength=$levelLength, extendedSize=$extendedSizeLevel")  if ($self->{debugMode});
#		$nbNGrams[$levelNo] = $tokensAsListRef?(scalar(@$tokens) - $extendedSizeLevel+1):(length($tokens) - $extendedSizeLevel+1);
# TODO possible bug here ($extendedSizeLevel >= $minNGrams) + return -1 ??
		if (!defined($minNGrams) || ($extendedSizeLevel >= $minNGrams)) {
			$atLeastOneLevelWithoutMinCondition = 1;
			my $pos = 0;
			my $nextNGram = $self->extractNGramFromPattern($levelNo, $tokens, $pos);
			while (defined($nextNGram)) {
#			    print "DEBUG XXX".join(";", @$nextNGram)."\n";
				$logger->debug("next ngram is '".join("|", @$nextNGram)."'") if ($self->{debugMode});
				my $idNGram = $self->addNGramLevel($nextNGram, $levelNo);
				$nbNGrams++;
				if ($distinctNGramsHashRef) {
					$distinctNGramsInThis{$idNGram} = 1;
				}
				$pos++;
				$nextNGram = $self->extractNGramFromPattern($levelNo, $tokens, $pos);
			}
			$self->addDocumentNgramsToCountVector($distinctNGramsHashRef->{$levelNo}, \%distinctNGramsInThis) if ($distinctNGramsHashRef);
		}
	}
	return $nbNGrams;
}

=head2 getLevelExtendedSize($level)

returns the "extended size" for skip-grams, e.g. 3 for "Y N Y"
returns the standard ngram length if this is aregular ngram

=cut

sub getLevelExtendedSize {
	my $self = shift;
	my $levelNo = shift;
	if (defined($self->{levelPattern}->{$levelNo})) {
		return scalar(@{$self->{levelPattern}->{$levelNo}});
	} else {
		return $self->{levelLength}->[$levelNo];
	}
}

=head2 extractNGramFromPattern($levelNo, $tokens, $startPosition)

given a sequence of tokens $tokens (as list or as string), extracts the next ngram corresponding to level $levelNo starting at position startPosition.
if startPosition is not defined, start at 0.
if the level does not contain a pattern (i.e. is a regular ngram, not a skip-gram), works the same (returns the first ngram from startPosition).
if there are not enough tokens left in $tokens, undef is returned.

returns the ngram, as list ref or string.

=cut

sub extractNGramFromPattern {
	my $self = shift;
	my $levelNo = shift;
	my $tokens = shift;
	my $startPosition = shift;
	my $tokensAsListRef = (ref($tokens) eq "ARRAY");
	my $maxLength = $tokensAsListRef?scalar(@$tokens):length($tokens);
	if (defined($self->{levelPattern}) && defined($self->{levelPattern}->{$levelNo})) {
		my $pattern = $self->{levelPattern}->{$levelNo};
		my $patternLength = scalar(@$pattern);
		my $pos = defined($startPosition)?$startPosition:0;
		if ($tokensAsListRef) {
			my @skipGram;
			for (my $i=0; $i <  $patternLength; $i++) {
				return undef if ($pos >= $maxLength); # not enough grams
				push(@skipGram, $tokens->[$pos]) if ($pattern->[$i]);
			}
			return \@skipGram;
		} else {
			my $skipGram = "";
			for (my $i=0; $i <  $patternLength; $i++) {
				return undef if ($pos >= $maxLength); # not enough grams
				$skipGram .= substr($tokens, $i, 1) if ($pattern->[$i]);
			}
			return $skipGram;
		}
	} else {
		return undef if ($startPosition + $self->{levelLength}->[$levelNo] > $maxLength);
		if ($tokensAsListRef) {
			my @ngram = @$tokens[$startPosition..$startPosition+$self->{levelLength}->[$levelNo]-1];
			return \@ngram;
		} else {
			return substr($tokens, $startPosition, $startPosition + $self->{levelLength}->[$levelNo]);
		}
	}
}





=head2 getKeyValueIterator()

error multiLevel

=cut

sub getKeyValueIterator {
	my $self = shift;
	$self->{logger}->logconfess("MultiLevelNGrams: use incValueFromKeyLevel instead.");
}

=head2 getKeyValueIteratorLevel($level)

ABSTRACT

=cut




1;
