#!/usr/bin/perl

# EM Dec 16
#
#


use strict;
use warnings;
use Carp;
#use Log::Log4perl;
use Getopt::Std;
#use CLGTextTools::ObsCollection;
#use CLGTextTools::Logging qw/@possibleLogLevels/;
#use CLGTextTools::DocProvider;
use CLGTextTools::Commons qw/readTextFileLines/;

binmode(STDOUT, ":utf8");

my $progNamePrefix = "char-info"; 
my $progname = "$progNamePrefix.pl";

my $obsType = "CHAR.C.lc0.sl0.mf1";
my $nbMostFreq = 10;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <file> [<file2> ...]\n";
	print $fh "\n";
	print $fh "  Prints information about the characters used in the text file(s).\n";
	print $fh "  If several files are provided, they are all considered as a single\n";
	print $fh "  document (i.e. as if they were concatenated into one large file).\n";
	print $fh "\n";
	print $fh "  Main options:\n";
	print $fh "     -h print this help message\n";
	print $fh "     -s ignore line breaks\n";
	print $fh "     -n <nb most frequent> number of most frequent chars to print\n";
	print $fh "\n";
}


sub printPercent {
    my $val = shift;
    my $total = shift;
    return sprintf("%7.3f%% (%6d)", $val*100/$total, $val);
}


# PARSING OPTIONS
my %opt;
getopts('hsn:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
print STDERR "at least 1 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) < 1);
my @files = @ARGV;

my $removeLineBreaks = $opt{s};
$nbMostFreq = $opt{n} if (defined($opt{n}));
my %params;

$params{obsTypes} = [ $obsType ];
$params{formatting} = 0;

my %chars;
my $length;
foreach my $file (@files) {
    my $textLines = readTextFileLines($file,$removeLineBreaks);
    foreach my $line (@$textLines) {
	foreach my $char (split //, $line) {
	    $chars{$char}++;
	    $length++;
	}
    }
}

print "\n$length chars:  [";
my @letters;
my $nbLetters;
my @punc;
my $nbPunc;
my @numbers;
my $nbNumbers;
my @others;
my $nbOthers;
foreach my $c (sort keys %chars) {
    my $other=1;
    my $cP = $c;
    if ($c =~ m/[\r]/) {
	$cP = '\r';
    } elsif ($c =~ m/[\n]/) {
	$cP = '\n';
    }
    print "$cP";
    if ($c =~ m/\p{L}/) {
	push(@letters, $cP);
	$nbLetters += $chars{$c};
	$other=0;
    }
    if ($c =~ m/\p{P}/) {
	push(@punc, $cP);
	$nbPunc += $chars{$c};
	$other=0;
    }
    if ($c =~ m/\p{N}/) {
	push(@numbers, $cP);
	$nbNumbers += $chars{$c};
	$other=0;
    }
    if ($other) {
	push(@others, $cP);
	$nbOthers += $chars{$c};
    }
}
print "]\n";

print printPercent($nbLetters, $length)." letter chars: [".join("", @letters)."]\n";
print printPercent($nbPunc, $length)." punct chars:  [".join("", @punc)."]\n";
print printPercent($nbNumbers, $length)." number chars: [".join("", @numbers)."]\n";
print printPercent($nbOthers, $length)." other chars:  [".join("", @others)."]\n";

print "\n$nbMostFreq most frequent chars:\n";
my @sorted = (sort { $chars{$b} <=> $chars{$a} } keys %chars);
for (my $i=0; $i< scalar(@sorted) && $i<$nbMostFreq; $i++) {
    print printPercent($chars{$sorted[$i]}, $length)."\t$sorted[$i]\n";
}
