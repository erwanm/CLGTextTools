#!/usr/bin/perl

# EM June 15
#
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Getopt::Std;
use File::Basename;
use CLGTextTools::DocCollection qw/createDatasetsFromParams/;
use CLGTextTools::Logging qw/@possibleLogLevels confessLog/;

my $progNamePrefix = "extract-observations-collection"; 
my $progname = "$progNamePrefix.pl";

my $defaultLogFilename = "$progNamePrefix.log";

my $filePrefixGlobalCount = "global";
my $filePrefixDocFreqCount = "doc-freq";

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <obs types> <path1> [<path2> ...] ]\n";
	print $fh "\n";
	print $fh "  Extracts features from a set of collections of text files.\n";
	print $fh "  The type of features is specified with <obs types>, which is a\n";
	print $fh "  list of 'observation types' separated with ':' (see the\n";
	print $fh "  documentation for a comprehensive list of obs types codes).\n";
	print $fh "  The output is written to separate files named after each\n";
	print $fh "  input file: <file1>.observations/<obs-type>.count and\n";
	print $fh "  <file1>.observations/<obs-type>.total\n";
	print $fh "  If POS observations are used, expects a file <file>.POS containing\n";
	print $fh "  the output in TreeTagger format (with lemma): \n";
	print $fh "   <token> <POS tag> <lemma>\n";
	print $fh "  Every collection is specified by a <path>, which is either a directory or a\n";
	print $fh "  file. In the former case, a pattern '*.txt' is used to find the document (see";
	print $fh "  also option -p). In the latter case, the file contains the list of all the\n";
	print $fh "  documents filenames.\n";

	print $fh "\n";
	print $fh "  Main options:\n";
#	print $fh "     -c <config file> TODO\n";
	print $fh "     -i read a list of input paths from STDIN. These are processed\n";
	print $fh "        the same way as filenames given on the command line.\n";
	print $fh "     -h print this help message\n";
	print $fh "     -l <log config file | Log level> specify either a Log4Perl config file\n";
	print $fh "        or a log level (".join(",", @possibleLogLevels)."). \n";
	print $fh "        By default there is no logging at all.\n";
	print $fh "     -L <Log output file> log filename (useless if a log config file is given).\n";
	print $fh "     -s <singleLineBreak|doubleLineBreak> by default all the text is collated\n";
	print $fh "        togenther; this option allows to specify a separator for meaningful units,\n";
	print $fh "        typically sentences or paragraphs.";
	print $fh "        (applies only to CHAR and WORD observations).\n";
	print $fh "     -t pre-tokenized text, do not perform default tokenization\n";
	print $fh "        (applies only to WORD observations).\n";
	print $fh "     -r <resourceId1:filename2[;resourceId2:filename2;...]> vocab resouces files\n";
	print $fh "        with their ids.\n";
	print $fh "     -m <min doc freq> discard observations with doc freq lower than <min doc freq>.\n";
	print $fh "     -p <file pattern> file pattern which gives the list of documents when located\n";
	print $fh "        in the dataset path. Default: '*.txt'\n";
	print $fh "     -g generate also count files for the whole dataset (sum of the counts); for\n";
	print $fh "        every <obs type> the count file\n";
	print $fh "        <dirname>/[global|doc-freq].observations/<obs type>.count\n";
	print $fh "        is generated. <dirname> is <path> if <path> is a directory, the directory\n";
	print $fh "        contaning the list file otherwise.\n";
	print $fh "     -f force writing count files even if they already exist (default: only if the.\n";
	print $fh "        files don't exist yet.\n";
	print $fh "\n";
}




# PARSING OPTIONS
my %opt;
getopts('ihl:L:t:r:s:m:p:gf', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage(*STDOUT) && exit 0 if $opt{h};
print STDERR "at least 1 argument expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) < 1);
my $obsTypesList = shift(@ARGV);
my @datasetsPaths = @ARGV;
# init log
my $logger;
if ($opt{l} || $opt{L}) {
    CLGTextTools::Logging::initLog($opt{l}, $opt{L} || $defaultLogFilename);
    $logger = Log::Log4perl->get_logger(__PACKAGE__) ;
}

my $readFilesFromSTDIN = $opt{i};
my $formattingSeparator = $opt{s}; # unsure... defined($opt{s}) ? $opt{s} : 0 ;
my $performTokenization = ($opt{t}) ? 0 : 1;
my $resourcesStr = $opt{r};
my $minDocFreq = $opt{m};
my $filePattern  = $opt{p};
my $globalCountPrefix = $opt{g};
my $force=$opt{f};

my $vocabResources;
if ($opt{r}) {
    $vocabResources ={};
    my @resourcesPairs = split (";", $resourcesStr);
    foreach my $pair (@resourcesPairs) {
	my ($id, $file) = split (":", $pair);
#	print STDERR "DEBUG pair = $pair ; id,file = $id,$file\n";
	$vocabResources->{$id}->{filename} = $file;
    }
}

if ($readFilesFromSTDIN) {
    while (my $line = <STDIN>) {
	chomp($line);
	push(@datasetsPaths, $line);
    }
}

my %params;
$params{logging} = 1 if ($logger);

my @obsTypes = split(":", $obsTypesList);
$params{obsTypes} = \@obsTypes;
$params{wordTokenization} = $performTokenization;
$params{formatting} = $formattingSeparator;
$params{wordVocab} = $vocabResources if (defined($vocabResources));

$params{useCountFiles} = 1;
$params{forceCountFiles} = $force;

my %mapIdToPath;
my @ids;
my $num=1;
foreach my $collPath (@datasetsPaths) {
    my ($id, $path)   = ("dummy_dataset_id_$num", $collPath);
    if ($collPath =~ m/:/) {
        ($id, $path) = split (":", $collPath);
    }
    $mapIdToPath{$id} = $path;
    $num++;
    push(@ids, $id);
    $logger->debug("preparing parameters for dataset path = '$collPath'; id = '$id', path = '$path'") if ($logger);
}
confessLog($logger, "No dataset at all!") if (scalar(@ids) == 0);

my $datasets = createDatasetsFromParams(\%params, \@ids, \%mapIdToPath, $minDocFreq, $filePattern, $logger);
foreach my $dataset (keys %$datasets) {
    $datasets->{$dataset}->populateAll();
    if ($globalCountPrefix) {
	my $path = $mapIdToPath{$dataset};
	if (-f $path) { # list file
	    $path  = dirname($path);
	}
	my $globalCountDocProv = $datasets->{$dataset}->getGlobalCountDocProv() ;
	my $docFreqCountDocProv =  $datasets->{$dataset}->getDocFreqCountDocProv() ;

    }
}
