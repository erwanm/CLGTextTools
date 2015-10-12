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

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: count-ngrams-pattern.pl [options] <pattern> <output file>\n";
	print $fh "   Writes the number of occurrences for each distinct ngram and prints the\n";
	print $fh "   number of ngrams read as <nb distinct> <nb total>.\n";
	print $fh "   Pattern = an integer (length of n-grams) or a patern YNY (skip-grams)\n";
	print $fh "   Reads input file(s) on STDIN, one by line.\n";
	print $fh "   Input must be UTF-8 encoded.\n";
	print $fh "   Options:\n";
	print $fh "   -b do not ignore line breaks (w.r.t segmentation of n-grams where n>1)\n";
	print $fh "   -d: print debug information on STDERR\n";
	print $fh "   -c: characters n-grams instead of tokens (pattern must an integer).\n";
	print $fh "   -l: convert to lowercase before counting.\n";
	print $fh "   -s: strip punctuation from words. (not used if characters)\n";
	print $fh "   -t  header in output.\n";
	print $fh "   -v <vocabulary file[:col]> take into account all ngrams in the specified file, and\n";
	print $fh "      only these ngrams. The file must contain one ngram by line, and the output\n";
	print $fh "      file will follow the same order. 'col' specifies the column (optional).\n";
	print $fh "   -m <min frequency> ignore n-grams which appear less than <min frequency> times.\n";
	print $fh "      The discarded ngrams are still counted in the number of distinct/total ngrams.\n";
	print $fh "      Warning: not compatible with -v (a warning is issued).\n";
	print $fh "\n";
}

# PARSING OPTIONS
my %opt;
getopts('m:dhlsctv:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
my $toLowercase = $opt{l};
my $stripPunctuation = $opt{s};
my $vocabFile = $opt{v};
my $header = $opt{t};
my $charNGrams = $opt{c};
my $debugMode = $opt{d};
my $minFreq = 0;
my $ignoreLineBreaks = $opt{b}?0:1;
if (defined($opt{m})) {
    if (defined($vocabFile)) {
	print STDERR "Warning: option -m is not compatible with option -v, -m will be ignored.\n";
    } else {
	$minFreq= $opt{m};
    }
}
my $pattern = $ARGV[0];
my $output = $ARGV[1];


my $fh;
my %frequency;
my @vocabNGrams=();

if (defined($vocabFile)) {
	my ($file, $col) = ($vocabFile, undef);
	if ($vocabFile =~ m/.+:.+/) {
		($file, $col) = ($vocabFile =~ m/^(.+):([^:]+)/);
	}
	open($fh, '<:encoding(UTF-8)', $file) or die "Can't open '$file' for reading: $!";
	while (<$fh>) {
		chomp;
		my $ngram = $_;
		if (defined($col)) {
			my @t = split(/\t/, $ngram);
			$ngram = $t[$col-1];
		}
#		print "DEBUG: $token\n";
		push(@vocabNGrams, $ngram);
		$frequency{$ngram} = 0;
	}
	close($fh);
	if (scalar(@vocabNGrams)==0) {
		print "Error: no vocabulary loaded.\n";
		exit(4);
	}
#	print "DEBUG: ".scalar(@vocabTokens).".\n";
}


my $tokenizer = $charNGrams ? 
    Text::TextAnalytics::Tokenizer::CharTokenizer->new({ "toLowercase" => $toLowercase, "mergeWhitespaces" => 1}) : 
    Text::TextAnalytics::Tokenizer::BasicWordTokenizer->new({ "toLowercase" => $toLowercase , "detachPunctuation" => $stripPunctuation });
my $ngrams = $charNGrams ?  
    Text::TextAnalytics::NGrams::CharsBagOfNGrams->new({ n => $pattern }) :
    Text::TextAnalytics::NGrams::IndexedMultiLevelNGrams->new({ "n" => $pattern, "nGramsClassName" => "HashByGramIndexedBagOfNGrams", "nGramsParams" => { "storeWayBackToNGram"=>1 } }) ;

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

    if ($ignoreLineBreaks) {
	my $content="";
	while (<$fh>) {
	    #    print "DEBUG $_";
	    chomp;
	    $content .= " $_";
	}
	my $tokens = $tokenizer->tokenize($content);
	$ngrams->addTokens($tokens);
    } else {
	while (<$fh>) {
	    #    print "DEBUG $_";
	    chomp;
	    my $tokens = $tokenizer->tokenize($_);
	    $ngrams->addTokens($tokens);
	}
    }
	close($fh);
}


my $iterNext =  $charNGrams ? $ngrams->getKeyValueIterator() : $ngrams->getKeyValueIteratorLevel(0);
while (my ($key, $value) = $iterNext->() ) { # not optimized!!
#	    print "DEBUG $key $value\n";
    my $ngram;
    if ($charNGrams) {
	$ngram = $key;
    } else {
	my $ngramList = $ngrams->getNGramFromKeyLevel($key, 0);
#		print "DEBUG ".join(";", @$ngramList)."\n";
	$ngram = join(" ",@$ngramList);
#		print "DEBUG3 : $ngram\n";
    }
    $nbNGrams += $value;
    if (!defined($vocabFile) || defined($frequency{$ngram})) {
	$frequency{$ngram} = $value;
    }
}

if ($nbNGrams == 0) {
	print STDERR "Error: no ngram found in input file(s).\n";
	exit(5);
}

open($fh, '>:encoding(UTF-8)', $output) or die "Can't open '$output' for writing: $!";

if ($header) {
	print $fh "token\tfrequency\trelFreq\n"; 
}
if (!$vocabFile) {
	@vocabNGrams = (sort keys %frequency);
#	print join("  ", @vocabNGrams);
}
my $nbDistinct=0; # because of possible -v
foreach my $ngram (@vocabNGrams) {
#	    print "   DEBUG $ngram\n";
	my $relFreq = $frequency{$ngram} / $nbNGrams;
	if ($frequency{$ngram}>=$minFreq) {
	    printf $fh "%s\t%d\t%.10f\n", $ngram, $frequency{$ngram}, $relFreq ;
	}
	$nbDistinct++ if ($frequency{$ngram} > 0);
}
close($fh);	
print "$nbDistinct\t$nbNGrams\n";
