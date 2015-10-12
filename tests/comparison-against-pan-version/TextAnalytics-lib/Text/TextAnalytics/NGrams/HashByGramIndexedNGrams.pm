package Text::TextAnalytics::NGrams::HashByGramIndexedNGrams;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::IndexedNGrams;
use Text::TextAnalytics::NGrams::BagOfNGrams;
use Scalar::Util 'blessed';

our @ISA = qw/Text::TextAnalytics::NGrams::IndexedNGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::HashByGramIndexedNGrams - ABSTRACT Indexed NGrams collection,
implemented with a hash indexing "grams" (e.g. "b" in trigram [a,b,c]). 


=cut

my $defaultIndexSeparator="-";

my %defaultOptions = (  
					   "storeWayBackToNGram" => 0 
					  ); 

my @parametersVars = (
					   "storeWayBackToNGram" 
					 );


=head1 DESCRIPTION

ISA = Text::TextAnalytics::NGrams::IndexedNGrams

Designed to save space in the case of words ngrams; this class is implemented in
HashByGramIndexedBagOfNGrams and HashByGramIndexedSequenceOfNGrams.


=head2 new($class, $params)

Mandatory parameter: $params->{n}.
Optional parameter: $params->{shared}.
Optional parameter: $params->{storeWayBackToNGram}.


creates a new HashByGramIndexedNGram object, defined to deal with N-grams where N is the parameter. 
If the 'shared' parameter is provided, the object created will use the same index as the HashByGramIndexedNGram object provided (shared index, see superclass).
storeWayBackToNGram is set to false by default. If true, the structure stores not only a hash from ngram to key but also from key to ngram.
This permits to recover the ngram quicky, otherwise it is searched among all possible keys (very inefficient). 
use it only it is necessary to be able to obtain (efficiently) the actual words corresponding to a given ngram : otherwise once "coded" (indexed) it is not intended to
be decoded.

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	my $logger = $self->{logger};
	$logger->debug("Initializing");
	# if the reference is defined, use its own index as index, otherwise create a new empty one.
	if (defined($self->{shared})) {
		$logger->logconfess("Invalid reference object to shared index: not blessed") unless (blessed($self->{shared}));
		$logger->debug("shared index");
# no such constraints anymore: must be possible to compare to a MultiLevelNGrams object 
#		$logger->logconfess("Invalid reference object to shared index: not a ".__PACKAGE__." instance (object class is '".ref($self->{shared})."')") unless ($self->{shared}->isa(__PACKAGE__)); 
#		$logger->logconfess("Incompatible reference: N value for the reference is ".$self->{shared}->getN()." (value provided: ".$self->{n}.")") if (defined($self->{shared}) && ($self->{shared}->getN() != $self->{n}));
# TODO dirty trick (I'm not even sure?)
		my $data = $self->{shared}->getSharedData();
		$self->{index} = $data->{index};
		$self->{refNbIndexes} = $data->{refNbIndexes};
		$self->{refKeySeparator} = $data->{refKeySeparator};
		if ($self->{storeWayBackToNGram}) {
			$self->{backToGram} = $data->{storeWayBackToNGram}?$data->{backToGram}:[]; # maybe possible problems if one has this option and the other does not??
		}
	} else {
		$self->{index} = {};
		my $i = 0;
		$self->{refNbIndexes} = \$i;
		$self->{refKeySeparator} = \$defaultIndexSeparator;
		$self->{backToGram} = [] if ($self->{storeWayBackToNGram});
	}
#	$logger->trace("Created a ".__PACKAGE__." object $self, with index ".$self->{index}."") if ($self->{debugMode});
	bless($self, $class);
	return $self; 
}


# TODO 

sub getSharedData {
	my $self = shift;
	return $self;
}

=head2 tokensAreCharacters()

returns false.

=cut

sub tokensAreCharacters {
	return 0;
}




=head2 shareIndexWith($otherNGramsCollection)

see superclass

=cut

sub shareIndexWith {
	my $self = shift;
	my $otherNGram = shift;
	$self->{logger}->logconfess("Invalid reference object to shared index (object is not blessed)") unless (blessed($otherNGram));
#	$self->{logger}->logconfess("Invalid reference object to shared index (object is not a ".__PACKAGE__.")") unless ($otherNGram->isa(__PACKAGE__));
#	die "UNDEFINED FIRST INDEX" if (!defined($self->{index}));
#	die "UNDEFINED SECOND INDEX" if (!defined($otherNGram->{index}));
	return ($self->{index} == $otherNGram->{index});
}


#
# TODO VERY VERY DIRTY
#
sub returnKeyFromList {
	my $self = shift;
	my $l= shift;
	return join(${$self->{refKeySeparator}}, @$l);
}

=head2 getNGramFromKey($key)

see superclass.
very unefficient by default (if storeWayBackToNGram is false), use only for small objects or for debuging purpose
returns undef if invalid index.

=cut

sub getNGramFromKey {
	my $self=shift;
	my $key=shift;
	my @ngram = ();
		
	foreach my $gramIndex (split(/${$self->{refKeySeparator}}/, $key)) {
#	    print "DEBUG A $gramIndex\n";
		my $gram;
		if ($self->{storeWayBackToNGram}) {
			$gram = $self->{backToGram}->[$gramIndex];
#			print "DEBUG B $gram\n";
		} else {
			foreach my $g (keys %{$self->{index}}) {
				if ($self->{index}->{$g} eq $gramIndex) {
					$gram = $g;
					last;
				}
			}
		}
		return undef if (!defined $gram);
		push(@ngram, $gram);
	} 
#	print "DEBUG C ".join(";", @ngram)."\n";
	return \@ngram;
}


=head2 getKey($ngram)

see superclass. stops with an error if ngram is not the right length. 

=cut

sub getKey {
	my $self = shift;
	my $ngram = shift;
	if (scalar(@$ngram) != $self->{n}) {
		$self->{logger}->logconfess("wrong number of grams: ".scalar(@$ngram)." read, ".$self->{n}." expected.");
	}
#	print "debug getIndex: ".join(";", @$ngram)."\n";
	my $index = "";
	for (my $i=0; $i<scalar(@$ngram); $i++) {
		my $gramIndex = $self->{index}->{$ngram->[$i]};
		if (defined $gramIndex) {
			$index .= $gramIndex.${$self->{refKeySeparator}};
		} else {
			return undef;
		}
	}
	chop($index);
	return $index;
}




=head2 createKey($ngram)

creates a new ngram in the structure and returns this new key
reports a warning if the ngram already exists.

=cut

sub createKey {
	my ($self, $ngram) = @_;
	my $index = "";
	my $new=0;
	for (my $i=0; $i<scalar(@$ngram); $i++) {
		my $gramIndex = $self->{index}->{$ngram->[$i]};
		if (!defined $gramIndex) {
			$new=1;
			$gramIndex = ${$self->{refNbIndexes}};
			$self->{index}->{$ngram->[$i]} = $gramIndex;
			$self->{logger}->debug("Creating key $gramIndex for gram '".$ngram->[$i]."'") if ($self->{debugMode});
			${$self->{refNbIndexes}}++;
			$self->{backToGram}->[$gramIndex] = $ngram->[$i] if ($self->{storeWayBackToNGram});
#			$self->{logger}->debug("created index $gramIndex for gram '".$ngram->[$i]."'");
		}
		$index .= $gramIndex.${$self->{refKeySeparator}};
	}
	chop($index);
	$self->{logger}->logwarn("Trying to create an entry for existing ngram at index $index: ".join(";", @$ngram)) if (!$new);
	return $index;
}





=head2 getSharedKeysListRef()

see superclass.
possibly huge list! do not use with data containing a lot of different grams!

=cut

sub getSharedKeysListRef() {
	my $self = shift;
	my @vals = (0..${$self->{refNbIndexes}}-1);
	my $indexesAsLists = _allPossibleCombinations($self->{n}, \@vals);
	my @indexes = map(join(${$self->{refKeySeparator}}, @$_), @$indexesAsLists);
	return \@indexes;
}



# returns all combinations of length $n
sub _allPossibleCombinations {
	my ($n, $vals) = @_;
	return [[]] if ($n==0);
	my @allCombis;
	my $sublist = _allPossibleCombinations($n-1, $vals);
	foreach my $subCombi (@$sublist) {
		foreach my $val (@$vals) {
			my @combi = @$subCombi;
			push(@combi, $val);
			push(@allCombis, \@combi);
		}
	}
	return \@allCombis;
}



=head2 indexAsShortString()

see superclass

=cut

sub indexAsShortString {
	my ($self) = @_;
	my $res="(".${$self->{refNbIndexes}}.")";
	foreach my $key (sort keys %{$self->{index}}) {
		$res .= " '$key':$self->{index}->{$key}";
	}
	return $res;
}


1;
