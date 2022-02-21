#!/usr/bin/perl


use strict;
use warnings;
use Carp;
use Getopt::Std;




sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: extract-continuous-sample.pl <input filename> <size of sample  (in lines)>\n";
	print $fh "\n";
	print $fh "   Writes output to STDOUT.\n";
	print $fh "\n";
	print $fh "  Options\n";
	print $fh "    -p include only complete paragraphs, i.e. remove first incomplete and\n";
	print $fh "       last incomplete paragraphs (separated by blank lines) (inal number\n";
	print $fh "       of lines depends on the data).\n";
	print $fh "\n";
}

# PARSING OPTIONS
my %opt;
getopts('p', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
confess "2 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
my $filename = $ARGV[0];
my $sampleSize = $ARGV[1];
my $onlyCompleteParags = $opt{p};

# reads input and stores it in an array (because we need to know the size)
open(INPUT, "<", $filename) or confess("can not open $filename");
my @data;
while (<INPUT>)  {
    chomp;
    push(@data, $_);
}
close(INPUT);

my $totalSize = scalar(@data);
my $startLine;
my $endLine;
if ($totalSize <= $sampleSize) {
    warn "Warning: not enough data in '$filename': $totalSize lines vs. $sampleSize required. Printing the full content.";
    $startLine = 0;
    $endLine = $totalSize-1;
} else {
    $startLine =  int(rand($totalSize - $sampleSize));
    $endLine = $startLine + $sampleSize;
    my ($startLine0, $endLine0) = ($startLine, $endLine);
    if ($onlyCompleteParags) {
	while (( $startLine<$endLine) && ($data[$startLine] !~ m/^\s*$/)) { # skip non empty lines
	    $startLine++;
	}
	while (($data[$startLine] =~ m/^\s*$/)) { # go to next non empty line
	    $startLine++;
	}
	confess("Error: no blank line found in the sample from line $startLine0") if ($startLine>=$endLine);
	
	while (( $startLine<$endLine) && ($data[$endLine--] !~ m/^\s*$/)) { # skip non empty lines
	    $endLine--;
	}
	confess("Error: no blank line found in the sample between line $startLine and line $endLine0") if ($startLine >$endLine);
	$endLine++;
    }
}
for (my $line=$startLine; $line<$endLine; $line++) { # print sample
    print "$data[$line]\n";
}
