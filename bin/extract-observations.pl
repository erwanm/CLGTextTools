#!/usr/bin/perl

# EM June 15
#
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Getopt::Std;
use CLGTextTools::ObsCollection;
use CLGTextTools::Logging qw/@possibleLogLevels/;
use CLGTextTools::Commons qw/readTextFileLines readLines/;

my $progNamePrefix = "extract-observations"; 
my $progname = "$progNamePrefix.pl";

my $defaultLogFilename = "$progNamePrefix.log";



sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <obs types> [<file1> [<file2>...] ]\n";
	print $fh "\n";
	print $fh "  Extracts features from a collection of text files.\n";
	print $fh "  The type of features is specified with <obs types>, which is a\n";
	print $fh "  list of 'observation types' separated with ':' (see the\n";
	print $fh "  documentation for a comprehensive list of obs types codes).\n";
	print $fh "  The output is written to separate files named after each\n";
	print $fh "  input file: <file1>.<obs-type>.count and <file1>.<obs-type>.total\n";
	print $fh "  If <file1> is '-', then STDIN is used and the output is printed\n";
	print $fh "  to STDOUT (no other input file is accepted).\n";
	print $fh "\n";
	print $fh "  Remark: This program cannot deal with POS obs types.\n";
	print $fh "\n";
	print $fh "  Main options:\n";
#	print $fh "     -c <config file> TODO\n";
	print $fh "     -i read a list of input filenames from STDIN. These are processed\n";
	print $fh "        the same way as filenames given on the command line.\n";
	print $fh "     -h print this help message\n";
	print $fh "     -l <log config file | Log level> specify either a Log4Perl config file\n";
	print $fh "        or a log level (".join(",", @possibleLogLevels)."). \n";
	print $fh "        By default there is no logging at all.\n";
	print $fh "     -L <Log output file> log filename (useless if a log config file is given).\n";
	print $fh "     -s interpret line breaks as sentence ends (default: collate all\n";
	print $fh "        the text in a file together).\n";
	print $fh "     -t pre-tokenized text, do not perform default tokenization (applies only\n";
	print $fh "        to WORD observations).\n";
	print $fh "     -r <resourceId1:filename2[;resourceId2:filename2;...]> vocab resouces files\n";
	print $fh "        with their ids.\n";
	print $fh "\n";
}


# PARSING OPTIONS
my %opt;
getopts('ihl:L:t:r:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
print STDERR "at least 1 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) < 1);
my $obsTypesList = shift(@ARGV);
my @files = @ARGV;
# init log
my $logger;
if ($opt{l} || $opt{L}) {
    CLGTextTools::Logging::initLog($opt{l}, $opt{L} || $defaultLogFilename);
    $logger = Log::Log4perl->get_logger(__PACKAGE__) ;
}

my $readFilesFromSTDIN = $opt{i};
my $sentenceByLine = $opt{s};
my $performTokenization = 0 if ($opt{t});
my $resourcesStr = $opt{r};
my $vocabResources;
if ($opt{r}) {
    $vocabResources ={};
    my @resourcesPairs = split (";", $resourcesStr);
    foreach my $pair (@resourcesPairs) {
	my ($id, $file) = split (":", $pair);
#	print STDERR "DEBUG pair = $pair ; id,file = $id,$file\n";
	$vocabResources->{$id} = $file;
    }
}

if ($files[0] eq "-") {
    confessLog($logger, "Error: using '-' as input file is not compatible with additional input files") if (scalar(@files)>1);
    confessLog($logger, "Error: using '-' as input file is not compatible with option '-i'") if ($readFilesFromSTDIN);
}

my %params;
$params{logging} = 1 if ($logger);

my @obsTypes = split(":", $obsTypesList);
$params{obsTypes} = \@obsTypes;
$params{wordTokenization} = $performTokenization;
$params{wordVocab} = $vocabResources if (defined($vocabResources));

foreach my $file (@files) {
    my $textLines = ($file eq "-") ? readLines(*STDIN,0,$logger) : readTextFileLines($file,0,$logger);
    my $text = join("", @$textLines);
    $logger->debug("file '$file': content = '$text'") if ($logger);
    my $data = CLGTextTools::ObsCollection->new(\%params);
    $data->addText($text);
    if ($file eq "-") { 
	foreach my $obsType (@obsTypes) {
	    $data->writeObsTypeCount(*STDOUT, $obsType, 1) ;
	}
    } else {
	$data->writeCountFiles($file);
    }
}
