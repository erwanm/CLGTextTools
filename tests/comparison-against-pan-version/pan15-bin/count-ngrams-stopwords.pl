#!/usr/bin/perl

# EM 12/02/13


use strict;
use warnings;
use Getopt::Std;
use Text::TextAnalytics::Tokenizer::BasicWordTokenizer;
use Text::TextAnalytics::Tokenizer::CharTokenizer;
use File::BOM qw/open_bom/;
use Text::TextAnalytics::HighLevelComparator::StdHLComparator;
use Text::TextAnalytics qw/@possibleLogLevels $prefixModuleHighLevelComparator genericObjectBuilder parseObjectDescription parseParametersFile/;
use Text::TextAnalytics::NGrams::IndexedMultiLevelNGrams;
use Text::TextAnalytics::NGrams::CharsBagOfNGrams;
use Log::Log4perl qw(:easy);

my $progName="count-ngrams-stopwords.pl";

my $toLowercase = 1;
my $stripPunctuation = 1;
my $blank = "___";

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName [options] <stop words file> <N> <output file>\n";
	print $fh "\n";
	print $fh "   count words N-grams, replacing any non-stop word by '$blank'.\n";
	print $fh "\n";
	print $fh "   Writes the number of occurrences for each distinct ngram and prints the\n";
	print $fh "   number of ngrams read as <nb distinct> <nb total>.\n";
	print $fh "   Reads input file(s) on STDIN, one by line.\n";
	print $fh "   Input must be UTF-8 encoded. assumes lowercased stop words, stripped punctuation from words (punctuiation can be in thestop words list).\n";
	print $fh "\n";
	print $fh "   Options:\n";
	print $fh "   -d: print debug information on STDERR\n";
	print $fh "   -m <min frequency> ignore n-grams which appear less than <min frequency> times.\n";
	print $fh "      The discarded ngrams are still counted in the number of distinct/total ngrams.\n";
	print $fh "\n";
}

# PARSING OPTIONS
my %opt;
getopts('dm:h', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "3 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 3);
my $debugMode = $opt{d};
my $minFreq= defined($opt{m}) ? $opt{m}  :0;
my $stopFile = $ARGV[0];
my $N = $ARGV[1];
my $output = $ARGV[2];


my $fh;
my %stopWords;
my %frequency;

open($fh, '<:encoding(UTF-8)', $stopFile) or die "Can't open '$stopFile' for reading: $!";
while (<$fh>) {
    chomp;
    $stopWords{$_}=1;
}
close($fh);
if (scalar(keys %stopWords)==0) {
    print "Error: no stop words in '$stopFile'.\n";
    exit(4);
}


my $tokenizer = Text::TextAnalytics::Tokenizer::BasicWordTokenizer->new({ "toLowercase" => $toLowercase , "detachPunctuation" => $stripPunctuation });
my $ngrams = Text::TextAnalytics::NGrams::IndexedMultiLevelNGrams->new({ "n" => $N, "nGramsClassName" => "HashByGramIndexedBagOfNGrams", "nGramsParams" => { "storeWayBackToNGram"=>1 } }) ;

my $nbNGrams=0;

#			 "addTokensFrontiers" => 1, 

while (my $input = <STDIN>) {
    print STDERR "DEBUG reading $input" if ($debugMode);
    chomp($input);
    # PAN13 files contain BOM, hence open_bom. The usual version is here as backup, since apparently open_bom fails when the file doesn't contain a BOM.
    eval {
	open_bom($fh, $input, ':encoding(UTF-8)') or die "Can't open '$input' for reading: $!";
    };
    if ($@) {
	open($fh, '<:encoding(UTF-8)', $input) or die "Can't open '$input' for reading: $!";
    }

    my $content="";
    while (<$fh>) {
	#    print "DEBUG $_";
	chomp;
	$content .= " $_";
    }
    my $tokens = $tokenizer->tokenize($content);
    for (my $i=0; $i<scalar(@$tokens); $i++) {
	$tokens->[$i] = $blank if (!defined($stopWords{$tokens->[$i]}));
    }
    $ngrams->addTokens($tokens);
    close($fh);
}

my $iterNext =  $ngrams->getKeyValueIteratorLevel(0);
while (my ($key, $value) = $iterNext->() ) { # not optimized!!
#	    print "DEBUG $key $value\n";
    my $ngram;
	my $ngramList = $ngrams->getNGramFromKeyLevel($key, 0);
#		print "DEBUG ".join(";", @$ngramList)."\n";
	$ngram = join(" ",@$ngramList);
#		print "DEBUG3 : $ngram\n";
    $nbNGrams += $value;
    $frequency{$ngram} = $value;
}

if ($nbNGrams == 0) {
	warn "$progName warning: no ngram found in input from STDIN.";
}

open($fh, '>:encoding(UTF-8)', $output) or die "Can't open '$output' for writing: $!";

my $nbDistinct=0; 
foreach my $ngram (sort keys %frequency) {
#	    print "   DEBUG $ngram\n";
	my $relFreq = $frequency{$ngram} / $nbNGrams;
	if ($frequency{$ngram}>=$minFreq) {
	    printf $fh "%s\t%d\t%.10f\n", $ngram, $frequency{$ngram}, $relFreq ;
	}
	$nbDistinct++ if ($frequency{$ngram} > 0);
}
close($fh);	
print "$nbDistinct\t$nbNGrams\n";
