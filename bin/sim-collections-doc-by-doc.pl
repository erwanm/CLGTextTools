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
use CLGTextTools::SimMeasures::Measure qw/createSimMeasureFromId/;

my $progNamePrefix = "sim-collections-doc-by-doc"; 
my $progname = "$progNamePrefix.pl";

my $defaultLogFilename = "$progNamePrefix.log";

my $obsTypeSim = "WORD.T.lc1.sl1.mf1";
my $simMeasureId = "minmax";

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <obs types> <[id1:]path1> <[id2:]path2>\n";
	print $fh "\n";
	print $fh "  Extracts features from a set of collections of text files and\n";
	print $fh "  writes similarity scores for every pair of documents doc1 x doc2,\n";
	print $fh "  with <doc1> from <path1> and <doc2> from <path2>.\n";
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
	print $fh "  file. In the former case, a pattern '*.txt' is used to find the document (see\n";
	print $fh "  also option -p). In the latter case, the file contains the list of all the\n";
	print $fh "  documents filenames.\n";
	print $fh "  For every <file1> in <path1>, all the similarities against <path2> are\n";
	print $fh "  written to <file1>.simdir/<path2 id>.similarities, one file by line:\n";
	print $fh "  <file2> <sim score>\n";
	print $fh "\n";
	print $fh "  Main options:\n";
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
	print $fh "     -f force writing output files even if they already exist (default: only if the.\n";
	print $fh "        files don't exist yet).\n";
	print $fh "     -o <sim obs type> the obs type to use to compute similarities; default:\n";
	print $fh "        '$obsTypeSim'.\n";
	print $fh "     -S <sim measure params> specifiy a particular sim measure id instead of the\n";
	print $fh "        default '$simMeasureId'\n";
	print $fh "     -R <prefix> remove <prefix> from the filename for every doc id in the sim output\n";
	print $fh "         file (only for <file2> since the probe files are not written).\n";
	print $fh "\n";
}




# PARSING OPTIONS
my %opt;
getopts('hl:L:t:r:s:m:p:gfo:S:R:', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
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

my $formattingSeparator = $opt{s};
my $performTokenization = ($opt{t}) ? 0 : 1;
my $resourcesStr = $opt{r};
my $minDocFreq = $opt{m};
my $filePattern  = $opt{p};
my $globalCountPrefix = $opt{g};
my $force=$opt{f};
my $removePrefixSimFile2 = $opt{R};
$obsTypeSim = $opt{o} if (defined($opt{o}));
$simMeasureId = $opt{S} if (defined($opt{S}));

my $simMeasure = createSimMeasureFromId($simMeasureId, {}, 0); # TODO: no params possible currently


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
confessLog($logger, "Exactly two datasets paths must be supplied, ".scalar(@ids)." found.") if (scalar(@ids) != 2);

my $datasets = createDatasetsFromParams(\%params, \@ids, \%mapIdToPath, $minDocFreq, $filePattern, $logger, $removePrefixSimFile2);

# 1. populate and write count files
foreach my $dataset (keys %$datasets) {
    $datasets->{$dataset}->populateAll();
    if ($globalCountPrefix) {
	my $globalCountDocProv = $datasets->{$dataset}->getGlobalCountDocProv();
	my $docFreqCountDocProv = $datasets->{$dataset}->getDocProvCountDocProv();

    }
}

# 2. compute similarities
my $docs1 = $datasets->{$ids[0]}->getDocsAsHash();
my $docs2 = $datasets->{$ids[1]}->getDocsAsHash();
my ($file1, $doc1);
my ($file2, $doc2);
while (($file1, $doc1) = each %$docs1) {
    mkdir "$file1.simdir" if (! -d "$file1.simdir");
    my $outputFilename = "$file1.simdir/".$ids[1].".similarities";
    if ($force || (! -f $outputFilename) || (-z $outputFilename)) {
	my %simScores;
	while (($file2, $doc2) = each %$docs2) {
	    my $id2 = $doc2->getId();
	    $simScores{$id2} = $simMeasure->normalizeCompute($doc1, $doc2, $obsTypeSim);
	}
	my $fh;
	open($fh, ">", $outputFilename) or confessLog($logger, "Error: cannot open file '$outputFilename' for writing.");
	my ($id2, $score2);
	while (($id2, $score2) = each %simScores) {
	    print $fh "$id2\t$score2\n";
	}
	close($fh);
    }
}
