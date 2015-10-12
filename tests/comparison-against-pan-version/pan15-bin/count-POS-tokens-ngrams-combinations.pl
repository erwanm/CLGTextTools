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
	print $fh "Usage: count-POS-tokens-ngrams-combinations.pl [options] <pattern> <output file>\n";
	print $fh "   Reads the output of a POS tagger where each line is <token> <POS tag>.\n";
	print $fh "   Counts a particular combination of token/POS, e.g. 3-grams POS-token-POS.\n";
	print $fh "   Writes the number of occurrences for each distinct ngram and prints the\n";
	print $fh "   number of ngrams read as <nb distinct> <nb total>.\n";
	print $fh "   Pattern = a sequence [pt]+ describing the combination:\n";
	print $fh "   p=POS, t=token, s=skip\n";
	print $fh "   Reads input file(s) on STDIN, one by line.\n";
	print $fh "   Input must be UTF-8 encoded.\n";
	print $fh "   Options:\n";
	print $fh "   -d print debug information on STDERR\n";
	print $fh "   -t header in output.\n";
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
getopts('m:dhtv:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
my $vocabFile = $opt{v};
my $header = $opt{t};
my $debugMode = $opt{d};
my $minFreq = 0;
if (defined($opt{m})) {
    if (defined($vocabFile)) {
	print STDERR "Warning: option -m is not compatible with option -v, -m will be ignored.\n";
    } else {
	$minFreq= $opt{m};
    }
}
my $pattern = $ARGV[0];
my $output = $ARGV[1];


my @pattern;
print STDERR "pattern=$pattern\n" if ($debugMode);
for (my $i=0; $i< length($pattern); $i++) {
    my $c = lc(substr($pattern,$i,1));
    print STDERR "$i: c=$c\n"  if ($debugMode);
    if ($c eq "t") {
	push(@pattern, 0);
    } elsif ($c eq "p") {
	push(@pattern, 1);
    } elsif ($c eq "s") {
	push(@pattern, undef);
    } else {
	die "Error: unknown character $c in pattern";
    }
}
print STDERR "boolean pattern = ".join(";", @pattern)."\n"  if ($debugMode);

my $fh;
my %frequency;
my @vocabNGrams=();
my $nbNGrams=0;

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


my @windows = ([] , []); # first sublist = token window,  second = POS window
while (my $input = <STDIN>) {
    print STDERR "DEBUG reading $input" if ($debugMode);
    chomp($input);
    open($fh, '<:encoding(UTF-8)', $input) or die "Can't open '$input' for reading: $!";
    while(<$fh>) {
	chomp;
	my @cols = split(/\t/, $_);
	if (scalar(@{$windows[0]}) == scalar(@pattern)) {
	    shift(@{$windows[0]});
	    shift(@{$windows[1]}); # the size of the window never exeeds the size of the pattern
	}
	push(@{$windows[0]}, $cols[0]); # add to window whether it's never been full yet or it has
	push(@{$windows[1]}, $cols[1]);
	if (scalar(@{$windows[0]}) == scalar(@pattern)) {
	    my $ngram = $windows[$pattern[0]]->[0]; # warning: assuming the first item in the pattern is not SKIP
	    for (my $i=1; $i<scalar(@pattern); $i++) {
		$ngram .= " ".$windows[$pattern[$i]]->[$i]  if (defined($pattern[$i]));
	    }
	    $nbNGrams++;
	    print STDERR "ngram='$ngram' added\n" if ($debugMode);
	    if (!defined($vocabFile) || defined($frequency{$ngram})) {
		$frequency{$ngram}++;
	    }
	}
    }
    close($fh);
}


if ($nbNGrams == 0) {
	print STDERR "Error: no ngram found in input file(s).\n";
	exit(5);
}

open($fh, '>:encoding(UTF-8)', $output) or die "Can't open '$output' for writing: $!";


if ($header) {
	print $fh "ngram\tfrequency\trelFreq\n"; 
}
if (!$vocabFile) {
	@vocabNGrams = (sort keys %frequency);
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
