#!/usr/bin/perl



use strict;
use warnings;
use Getopt::Std;
use Carp;
use Text::TextAnalytics::Tokenizer::BasicWordTokenizer;
use File::BOM qw/open_bom/;

my $progName="count-word-length.pl";



sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName [options] <input file> <output file>\n";
	print $fh "\n";
	print $fh "   TODO counts special observation type WORDLENGTH\n";
	print $fh "\n";
	print $fh "   Options:\n";
	print $fh "     -h print this help\n";
	print $fh "     -c <set1:set2:...:setN> specify ranges instead of considering\n";
	print $fh "        the raw length, e.g. 1-4:5-9:10-100 will assign tokens to\n";
	print $fh "        only 3 classes (lower than 5, between 5 and 9, more than 9)\n";
	print $fh "        Remark: no sanity check!\n";
	print $fh "\n";
}


sub getLengthClass {
    my $token=  shift;
    my $ranges =shift;
    if (defined($ranges)) {
	my $l = length($token);
	for (my $i=0; $i< scalar(@$ranges); $i++) {
	    return "class.".$i if (($l >= $ranges->[$i]->[0]) && ($l <= $ranges->[$i]->[1]));
	}
    } else {
	return "class.".length($token);
    }
}


sub parseRanges {
    my $s = shift;
    my @strRanges  = split(":", $s);
    my @res;
    foreach my $sRange (@strRanges) {
	my ($min, $max) = ($sRange =~ m/(\d+)-(\d+)/);
	push(@res, [$min, $max]);
    }
    return \@res;
}


# PARSING OPTIONS
my %opt;
getopts('hc:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
my $inputFile=$ARGV[0];
my $outputFile=$ARGV[1];
my $ranges=parseRanges($opt{c}) if (defined($opt{c}));

my %classes;
my $total=0;


# PAN13 files contain BOM, hence open_bom. The usual version is here as backup, since apparently open_bom fails when the file doesn't contain a BOM.
my $fh;
my $tokenizer =  Text::TextAnalytics::Tokenizer::BasicWordTokenizer->new({ "toLowercase" => 0 , "detachPunctuation" => 1 });
eval {
    open_bom($fh, $inputFile, ':encoding(UTF-8)') or die "Can't open '$inputFile' for reading: $!";
};
if ($@) {
    open($fh, '<:encoding(UTF-8)', $inputFile) or die "Can't open '$inputFile' for reading: $!";
}

my $content="";
while (<$fh>) {
    #    print "DEBUG $_";
    chomp;
    $content .= " $_";
}
my $tokens = $tokenizer->tokenize($content);
#$ngrams->addTokens($tokens);
foreach my $token (@$tokens) {
    my $class = getLengthClass($token, $ranges);
#    print "DEBUG: '$token' -> $class'\n";
    $classes{$class}++;
    $total++;
}
close($fh);





open(OUT, ">", $outputFile) or die "$progName: cannot write to '$outputFile'";
foreach my $class (sort keys %classes) {
    my $relFreq = $classes{$class} / $total;
    printf OUT "%s\t%d\t%.10f\n", $class, $classes{$class}, $relFreq ;
}
close(OUT);
open(OUT, ">", "$outputFile.total") or die "$progName: cannot write to '$outputFile.total'";
print OUT "".scalar(keys %classes)."\t$total\n";
close(OUT);


