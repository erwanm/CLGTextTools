package Text::TextAnalytics::NGrams::NGrams;


use strict;
use warnings;
use Carp;
use Test::More;
use Text::TextAnalytics qw/getParametersStringGeneric/;
use Log::Log4perl;

our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::NGrams - Abstract class for NGrams collections

=cut

our @parametersVars = ( "n" );

=head2 new($class, $params)

creates a new N-grams collection, where N=$params->{n}.
$params is a hash ref defining at least the parameter n.

this method should be called by subclasses constructors because it initializes the logger object $self->{logger},
in order not to spend time calling 	Log::Log4perl->get_logger(__PACKAGE__) in the frequently executed methods.
Additionally a boolean $self->{debugMode} is set in order to (possibly) optimize calls to the logger: instead of
using $self->{logger}->is_debug() the method can test this variable, which is way faster. However using that disables
Log4perl mechanism about different categories (e.g. if the log config sets the DEBUG level for class X but not for this class
then nothing will be logged).

=cut

sub new {
	my ($class, $params) = @_;
	my $self;
	%$self=%$params;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);
	$self->{debugMode} = ($self->{logger}->is_debug)?1:0; # for efficiency
	$self->{logger}->debug("debug mode is ON") if ($self->{debugMode});
	$self->{logger}->logcroak("Parameter N must be defined to create an N-gram.") if (!defined($self->{n}));
	bless($self, $class);
	return $self;
}


=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = getParametersStringGeneric($self, \@parametersVars,$prefix);
	return $str;
}


=head2 getN()

get N (size of N-grams)

=cut

sub getN {
	my $self = shift;
	return $self->{n};	
}


=head2 tokensAreCharacters()

ABSTRACT

returns true if tokens are supposed to be characters, false if tokens are strings.

=cut

=head2 getTotalCount()

ABSTRACT

returns the total number of ngrams. warning: only ngrams which have been added using addTokens/addNGram are taken into account.

=cut


=head2 addNGram($ngram)

ABSTRACT

adds $ngram to this object using the default method (depending on the class) and returns its key.

=cut



=head2 addNGramFromKey($key)

ABSTRACT

adds the ngram defined by this key using the default method (depending on the class).

=cut


=head2 getNGramFromKey($key)

ABSTRACT

usually very unefficient, use only for small objects or for debuging purpose

=cut



=head2 getKey($ngram)

ABSTRACT

returns the internal representation of the given ngram. returns undef if ngram does not exist.

=cut


=head2 ngramsAreOrdered()

ABSTRACT

returns true if and only if the order matters for all high level methods: getNGramsListRef, getKeysListRef, addTokens, doForAllNGrams, prettyPrint.
basically, false for bags of ngrams, true for sequences of ngrams.

see also ngramsAreUnique().
 
=cut


=head2 ngramsAreUnique()

ABSTRACT

returns true if and only if only any ngram appears at most once in the list for all high level methods: getNGramsListRef, getKeysListRef, doForAllNGrams, prettyPrint.
basically, true for bags of ngrams, false for sequences of ngrams.

see also ngramsAreOrdered().
 
=cut



=head2 	getNGramsListRef()

ABSTRACT

returns the list (as a ref) of of all ngrams possibly contained in the structure (i.e. all ngrams contained are in the list but the list can contain more ngrams)
important: the ngrams in this list are expected to be provided as lists refs, and are supposed to be usable as a parameter with getKey

=cut



=head2 getKeysListRef()

ABSTRACT

returns a ref to a list of ngrams keys which internally represent the ngrams. must be usable with getNGramsFromKey

=cut

=head2 getKeyValueIterator()

ABSTRACT

returns an iterator sub. on (key, values) elements. should be more efficient than other methods in general.
WARNING: no other iteration of any kind on the object must be done in the same time.


=cut



=head2 addTokens($tokens, $distinctNGramsHashRef, $minNGrams)

adds a set/sequence of tokens to the object.
if the second (optional) parameter is provided, $distinctNGramsHashRef->{id(X)} will be incremented for every distinct ngram X in $listRef (useful for IDF)
if the 3rd parameter $minNGrams is provided, then the tokens are added only if the total number of ngrams to add is at least $minNGrams.

returns the number of ngrams actually added, or -1 if $minNGrams was provided and the condition was not satisfied. note that a return value of 0 or -1 
means the same for this method, the difference is only provided in order to inform the caller of the (first) reason why no ngrams were added. In other words
the caller can test if return value > 0 if the goal is to know if any ngram was added, or if return value > 0 if the goal is to know whether the segment was skipped. 

update: can take as input both a list ref or a string (in which case ngrams are characters)

see also ngramsAreOrdered(), ngramsAreUnique().

=cut

sub addTokens {
	my ($self, $tokens, $distinctNGramsHashRef, $minNGrams) = @_;
	my %distinctNGramsInThis;
	my $n = $self->getN();
	my $tokensAsListRef = (ref($tokens) eq "ARRAY");
	my $nbNGrams = $tokensAsListRef?(scalar(@$tokens) - $n+1):(length($tokens) - $n+1);
	$nbNGrams = 0 if ($nbNGrams<0);
	if (defined($minNGrams) && ($nbNGrams < $minNGrams)) {
		return -1;
	} else {
		for (my $i=0; $i < $nbNGrams; $i++) {
			my $idNGram;
			if ($tokensAsListRef) {
				my @ngram = @$tokens[$i..$i+$n-1];
				$idNGram = $self->addNGram(\@ngram);
			} else {
				$idNGram = $self->addNGram(substr($tokens, $i, $n));
			}
			if ($distinctNGramsHashRef) {
				$distinctNGramsInThis{$idNGram} = 1;
			}
		}
		$self->addDocumentNgramsToCountVector($distinctNGramsHashRef, \%distinctNGramsInThis) if ($distinctNGramsHashRef);
		return $nbNGrams;
	}
}



=head2 addDocumentNgramsToCountVector($ngramsAllHash, $ngramsThisHash)

increments $ngramsAllHash->{$idNGram} for every idNGram in $ngramsThisHash

=cut

sub addDocumentNgramsToCountVector {	
	my ($self, $distinctNGramsHashRef, $distinctNGramsInThis) = @_;
	foreach my $idNGram (keys %$distinctNGramsInThis) {
		$distinctNGramsHashRef->{$idNGram}++;
	}
}

=head2 doForAllNGrams($sub)

apply subroutine $sub to every ngram in the collection in the following way:
$sub->($ngramsCollection, $ngram, $value, $ngramKey)
where $ngramKey is an element of the list returned by getKeysListRef().
if sub returns 0/undef the process stops and the value is returned, so it MUST NOT return 0/undef in all other cases.
returns 0 if interruption (sub returned 0), any non-zero value otherwise.
Usually very unefficient.

=cut

sub doForAllNGrams {
	my ($self, $sub) = @_;
	foreach my $key (@{$self->getKeysListRef()}) {
		if (!$sub->($self, $self->getNGramFromKey($key), $self->getValueFromKey($key), $key)) {
			return 0;
		}
	}
	return 1;
}

=head2 prettyPrint($fileHandle)

prints a collection - not particularly efficient (depends on doForAllNGrams), so recommended for debug purpose only 

=cut

sub prettyPrint {
	my $self=shift;
	my $fh = shift;
	$fh = *STDOUT if (!defined($fh));
	my $printSub = sub {
		my ($self, $ngram, $value, $key) = @_;
#		print "debug prettyPrint: ngram=".(ref($ngram)?join(';', @$ngram):"not-a-ref")."\n";
		if (ref($ngram)) {
			$ngram = (join(';', @$ngram));
		}
		if ($fh) {
			print $fh ($ngram." (key '$key') ->".$value."\t ");
		} else {
			print STDOUT ($ngram." (key '$key') ->".$value."\t ");
		}
		return 1;
	};
	print $fh $self->getTotalCount()." - ";
	$self->doForAllNGrams($printSub); 
	print "\n";
}


=head2 valuesAsShortString($idfVector)

ABSTRACT 

returns a string representation of the ngrams collection, depends on the class.
$idfVector is an optional parameter.

=cut



=head2 valuesAsShortStringWithDetails($idfVector)

see valuesAsShortString (returns this string preceded by "(N)", where N is the total number of ngrams)

=cut

sub valuesAsShortStringWithDetails {
	my $self = shift;
	my $idfVector = shift; # optional

	return "(".$self->getTotalCount().")".$self->valuesAsShortString($idfVector);
}




=head2 testNGrams($onlyChars)

OBSOLETE!!!

a bunch of tests for ngrams classes. if onlyChars is set data is provided as strings of characters instead of lists of words.
probably not the right place but I don't know where this kind of test is supposed to be.

=cut

sub testNGrams {
	my ($class, $onlyChars) = @_;
	
	my @data1=qw/My wife is a magician : she turned our car into a tree ./;
	my $data1 = \@data1;
	my $nb1uniDistinct = 13;
	my $nb1uniTotal = 14;
	my @data2=qw/There is more than one way to do it ./;
	my $data2 = \@data2;
	my $nb123uniDistinct = 26;
	my $nb123uniTotal = 33;
	my $nb123biDistinct = 29;
	my $nb123biTotal = 30;
	my @data3=qw/ most of the time one way is enough ./;
	my $data3 = \@data3;
	my @ngram4 =qw/another one/;
	my $ngram4 = \@ngram4;
	my $searchedValue = "is a";
	if ($onlyChars) {
		$data1 = "magician";
		$data2="abracadabrantesque";
		$data3="musician";
		$ngram4="yz";
		$searchedValue="i a";
		$nb1uniDistinct = 6;
		$nb1uniTotal = 8;
		$nb123uniDistinct = 14;
		$nb123uniTotal = 34;
		$nb123biDistinct = 23;
		$nb123biTotal = 31;
	}

#	use Test::More;
	print "Testing NGrams subroutines...\n";
	use_ok($class);

	# unigrams
	my $ngrams = new_ok($class => [ 1 ] );	
#	isa_ok($ngrams, $class);
	isa_ok($ngrams, "Text::TextAnalytics::NGrams");
	ok($ngrams->addTokens($data1), "adding tokens (unigrams)");
	is($ngrams->getN(), 1, "getN");	
	is($ngrams->getNbDistinctNGrams(),$nb1uniDistinct,"nb distinct ngrams");
	is($ngrams->getTotalCount(), $nb1uniTotal,"nb inc calls");
	ok($ngrams->addTokens($data2)->addTokens($data3), "adding more tokens (unigrams)");
	is($ngrams->getNbDistinctNGrams(),$nb123uniDistinct,"nb distinct ngrams");
	is($ngrams->getTotalCount(), $nb123uniTotal,"nb inc calls");
	
	# bigrams
	$ngrams = new_ok($class => [ 2 ] );
	ok($ngrams->addTokens($data1), "adding tokens (bigrams)");
	is($ngrams->getN(), 2, "getN");	
	ok($ngrams->addTokens($data2) && $ngrams->addTokens($data3), "adding more tokens (bigrams)");
	is($ngrams->getNbDistinctNGrams(),$nb123biDistinct,"nb distinct ngrams");
	is($ngrams->getTotalCount(),$nb123biTotal,"nb inc calls");
	ok($ngrams->setValue($ngram4, 7), "set value");
	ok($ngrams->incValue($ngram4), "inc value");
	is($ngrams->getValue($ngram4), 8, "get value");
	ok($ngrams->getValue($ngram4), "get key");
	my $key =$ngrams->getKey($ngram4); 
	is($ngrams->getValue($ngram4), $ngrams->getValueFromKey($key), "get value from key"); 
	ok(($ngrams->getNGramFromKey($key)->[0] eq ($onlyChars?substr($ngram4,0,1):$ngram4->[0])) && ($ngrams->getNGramFromKey($key)->[1] eq ($onlyChars?substr($ngram4,1,1):$ngram4->[1])), "get ngram from key");
	
	# complex tests
	ok($ngrams->getNGramsListRef(), "get ngrams list");
	my $list = $ngrams->getNGramsListRef();
	is(@$list, $nb123biDistinct+1, "number of ngrams in list");
	my @scalarList = map(join(" ", @$_), @$list);
	is(grep(/^$searchedValue$/, @scalarList), 1, "some value is in the list");
	ok($ngrams->doForAllNGrams(sub {my ($x, $ng, $v)= @_; return 1 if (defined($v) && defined($ng) && ($v>0)); return 0; } ), "do for all ngrams");
	print "a prettyPrint output: ";
	ok($ngrams->prettyPrint(), "pretty print");
}


1;
