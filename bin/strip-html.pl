#!/usr/bin/perl

# EM 04/15


use strict;
use warnings;
use Getopt::Std;
use HTML::Strip;

my $minNbWordsParagraph=0;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: strip-html.pl [options] <html file> <output text file>\n";
	print $fh "\n";
	print $fh "   Extracts the text content from an HTML file.\n";
	print $fh "\n";
	print $fh "OPTIONS:\n";
	print $fh "  -p <min nb words>: after cleaning the HTML, remove any paragraph\n";
	print $fh "     contanining less than N words. A paragraph is defined as any\n";
	print $fh "     sequence of non-empty lines.\n";
	print $fh "\n";
	print $fh "\n";
}

# PARSING OPTIONS
my %opt;
getopts('hp:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "2 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) != 2);
$minNbWordsParagraph = $opt{p} if (defined($opt{p}));
my $inputHTML=$ARGV[0];
my $outputText=$ARGV[1];


my $fh;
open($fh, '<:encoding(UTF-8)', $inputHTML) or die "Can't open '$inputHTML' for reading: $!";
my $input;
while (<$fh>) {
    $input .= $_;
}
close($fh);

my $hs = HTML::Strip->new();
my $clean_text = $hs->parse( $input );
$hs->eof;

my @parag;
open(OUT, '>:encoding(utf-8)', $outputText) or die "Can't open '$outputText' for writing: $!";
for (split /^/, $clean_text) {
    chomp;
    if (m/./) { # non-empty line
	my @words = split;
	push(@parag, @words);
    } else { # empty line
	if (scalar(@parag)>0) {
	    if (scalar(@parag) >= $minNbWordsParagraph) {
		print OUT join(" ", @parag)."\n\n";
	    }
	    @parag=();
	}
    }
}
print OUT join(" ", @parag)."\n" if (scalar(@parag)>0);

close(OUT);

