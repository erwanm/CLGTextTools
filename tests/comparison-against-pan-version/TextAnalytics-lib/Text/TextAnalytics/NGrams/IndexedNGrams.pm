package Text::TextAnalytics::NGrams::IndexedNGrams;
        
use strict;
use warnings;
use Carp;
use Text::TextAnalytics::NGrams::NGrams;

our @ISA = qw/Text::TextAnalytics::NGrams::NGrams/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::NGrams::IndexedNGrams - Abstract class for NGrams collections using an index

ISA = Text::TextAnalytics::NGrams::NGrams
=cut


=head1 DESCRIPTION

The index permits to store only a 'key' instead of the ngram or a part of the ngram. Any subclass has
its own indexing system. Some subclasses permit to "share" the same index between different objets.

=cut

=head2 shareIndexWith($otherIndexedNGrams)

ABSTRACT

returns true if 1) the class can deal with shared indexes and 2) the current object and $otherIndexedNGrams share the same index

=cut

=head2 createKey($ngram)

ABSTRACT

creates a new key for $ngram in the index. Warning: does not necessarily check if the ngram is already indexed.

=cut


=head2 getNbSharedDistinctNGrams()

In case the class can deal with shared indexes, returns the number of distinct ngrams defined in the object index (which can be shared,
so maybe not all ngrams actually appear in the current object)

warning: subclasses are allowed not to implement this method: in this case undef is returned.

=cut

sub getNbSharedDistinctNGrams {
	return undef;
}



=head2 getSharedKeysListRef()

ABSTRACT

returns a superset of the list of shared keys, i.e a list containining all defined keys but also possibly some other ones.
Note that it's not even only the actual ngrams defined in the index, because some subclasses don't index the ngrams but the "grams".
this is why a "superset" is returned, which is only guaranteed to contain all actual ngrams.  

=cut




=head2 indexAsShortString()

ABSTRACT

returns a 'short representation' of the index data structure (for debugging purpose).
implementation is specific to the class

=cut




=head2 testIndexedNGrams()

OBSOLETE 

a bunch of tests for ngrams classes. 
probably not the right place but I don't know where this kind of test is supposed to be.

=cut

sub testIndexedNGrams {
	my ($class) = @_;

	my @data1=qw/My wife is a magician : she turned our car into a tree ./;
	my @data2=qw/There is more than one way to do it ./;
	my @data3=qw/ most of the time one way is enough ./;
	my @searchedValue = qw/our car/;

	use Test::More;
	print "Testing IndexedNGrams subroutines...\n";
	use_ok($class);
	Text::TextAnalytics::NGrams::testNGrams($class);
	
	my $ngrams = new_ok($class => [ 2 ] );	
	isa_ok($ngrams, "Text::TextAnalytics::NGrams::IndexedNGrams");
	$ngrams->addTokens(\@data1)->addTokens(\@data2);
	$ngrams->setValue(["another", "one" ], 7);
	ok(my $index = $ngrams->getKey(["another", "one" ]), "get index");
	is($ngrams->getValueFromKey($index), 7, "get value from index");
	ok($ngrams->setValueFromKey($index, 78), "set value from index");
	is($ngrams->getValueFromKey($index), 78, "get value from index 2");
	ok(my $ngram = $ngrams->getNGramFromKey($index), "get ngram from index");
	ok((scalar(@$ngram)==2) && ($ngram->[0] eq "another") && ($ngram->[1] eq "one"), "correct ngram recovered");
	
	# shared index
	my $nb1 = $ngrams->getNbDistinctNGrams();
	my $ngrams2 = new_ok($class => [ 2, $ngrams ] );
	ok($ngrams2->addTokens(\@data3), "adding bigrams to the second object with shared index");
	is($ngrams->getNbDistinctNGrams(), $nb1, "nb values in first object after adding data in the shared index");
	ok($ngrams->getKey(\@searchedValue) eq $ngrams2->getKey(\@searchedValue), "checking indexes are identical for both objects for a given word");
	my $l = $ngrams->getSharedKeysListRef();
	is(scalar@{$ngrams->getSharedKeysListRef()}, scalar@{$ngrams2->getSharedKeysListRef()}, "same number of (shared) indexes");
	ok(!$ngrams2->getValueFromKey($index), "try to get non existing value from index");
	my $nb2=0;
	$nb1=0;
	my $union=0;
	foreach my $index (@$l) {
		#print "debug: $index\t";
		my $i=defined($ngrams->getValueFromKey($index));
		my $j=defined($ngrams2->getValueFromKey($index));
		$nb1++ if ($i);
		$nb2++ if ($j);
		$union++ if ($i || $j);
	}
	## is($nb1+$nb2-$common, @$l, "right number of indexes in shared index"); invalid with new spec for getSharedKeysListRef()
	SKIP: {
		skip "getNbSharedDistinctNGrams() returns undef in this class", 1 unless defined($ngrams->getNbSharedDistinctNGrams());
		is($ngrams->getNbSharedDistinctNGrams(), $union, "right number of shared ngrams with getNbSharedDistinctNGrams()");
	}
	ok(my $l1 = $ngrams->getKeysListRef(), "get local indexes 1");	
	ok(my $l2 = $ngrams2->getKeysListRef(), "get local indexes 2");	
	is(scalar(@$l1), $nb1, "right number of indexes in local index 1");
	is(scalar(@$l2), $nb2, "right number of indexes in local index 2");
	my $ngrams3 = new_ok($class => [ 2 ] );
	ok ($ngrams->shareIndexWith($ngrams2),"share index with 1");
	ok (!$ngrams->shareIndexWith($ngrams3),"share index with 2");
}

1;
