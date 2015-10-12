#!/usr/bin/perl



use strict;
use warnings;
use Getopt::Std;
use Carp;
use Text::TextAnalytics::Tokenizer::BasicWordTokenizer;
use File::BOM qw/open_bom/;

my $progName="count-morph-words.pl";



sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName [options] <input file> <output file>\n";
	print $fh "\n";
	print $fh "   TODO counts special observation type MORPHWORD; also writes <output>.total\n";
	print $fh "\n";
	print $fh "   Options:\n";
	print $fh "     -h print this help\n";
	print $fh "\n";
}


sub getMorphClass {
    my $token=  shift;
    if ($token =~ m/^\p{Alpha}+$/) { # all alpha
	if ($token =~ m/^\p{Lowercase}+$/) { # all lower
	    return "allLowerCase";
	} elsif ($token =~ m/^\p{Uppercase}\p{Lowercase}*$/) { # first upper
	    return "firstUpperCase";
	} elsif ($token =~ m/^\p{Uppercase}+$/) { # all upper
	    return "allUpperCase";
	} else {
	    return "mixedCase";
	}
    } elsif ($token =~ m/^[-+]?[0-9]*\.?[0-9]+$/) {
	return "number";
    } elsif ($token =~ m/^[!?\.,;:"'()[\]]+$/) {
	return "punct";
    } else {
	return "misc";
    }

}


# PARSING OPTIONS
my %opt;
getopts('h', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
my $inputFile=$ARGV[0];
my $outputFile=$ARGV[1];

my %morph;
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
    my $morphClass = getMorphClass($token);
#    print "DEBUG: '$token' -> $morphClass'\n";
    $morph{$morphClass}++;
    $total ++;
}
close($fh);

open(OUT, ">", $outputFile) or die "$progName: cannot write to '$outputFile'";
foreach my $class (sort keys %morph) {
    my $relFreq = $morph{$class} / $total;
    printf OUT "%s\t%d\t%.10f\n", $class, $morph{$class}, $relFreq ;
}
close(OUT);
open(OUT, ">", "$outputFile.total") or die "$progName: cannot write to '$outputFile'";
print OUT "".scalar(keys %morph)."\t$total\n";
close(OUT);

