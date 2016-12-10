#!/usr/bin/perl

# EM Dec 16
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
use CLGTextTools::Stats qw/obsDistribByRelFreq distribQuantiles freqBins aggregateVector/;
use Data::Dumper;

binmode(STDOUT, ":utf8");



my $progNamePrefix = "profile-analysis"; 
my $progname = "$progNamePrefix.pl";

my $defaultLogFilename = "$progNamePrefix.log";


my $summaryOptions = "0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1:1:1:10";
my @printDistribQuantileLimits;
my $printDistribHighestFirst;
my $printCumulDistrib;
my $printNbCommonObs;
# todo options
my $printRelFreqMostCommon = 0;
my $printDocDetails = 1;
my $printStatSummary = 1;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "\n"; 
	print $fh "Usage: $progname [options] <obs types> <path1> [<path2> ...] ]\n";
	print $fh "\n";
	print $fh "  Performs a profile analysis for a set of collections of text files.\n";
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
#	print $fh "     -g generate also count files for the whole dataset (sum of the counts); for\n";
#	print $fh "        every <obs type> the count file\n";
#	print $fh "        <dirname>/[global|doc-freq].observations/<obs type>.count\n";
#	print $fh "        is generated. <dirname> is <path> if <path> is a directory, the directory\n";
#	print $fh "        containing the list file otherwise.\n";
	print $fh "     -f force writing count files even if they already exist (default: only if the\n";
	print $fh "        files don't exist yet.\n";
	print $fh "     -o <quantiles>:<highestFirst>:<cumulatedDistrib>:<nbMostCommonObs>\n";
	print $fh "        Options for printed summary. Default=''\n";
	print $fh "\n";
}




sub globalSummary {
    my ($data, $obsType, $globalCountDocProv, $docFreqCountDocProv, $logger) = @_;

    
    my %stats0;
    my %meta;
    my %commonObs;
    foreach my $datasetId (keys %$data) {
	$stats0{$datasetId} = docStats($globalCountDocProv->{$datasetId}, $obsType, $logger);
	addToMetaStats(\%meta, $stats0{$datasetId});
	# extract N most frequent by dataset for common obs
	for (my $i=0; $i < scalar(@{$stats0{$datasetId}->{distribs}->[0]}) && $i<$printNbCommonObs; $i++) {
	    $commonObs{$stats0{$datasetId}->{distribs}->[0]->[$i]} = 1;
	}
    }

    my $metaStats = aggregate(\%meta);
    print "\n\n**** $obsType, all datasets\n";
    datasetSummary(\%stats0, $metaStats);
    

    %meta = ();
    my %statsDataset;
    my %metaStatsDataset;
    foreach my $datasetId (keys %$data) {
	my $docs = $data->{$datasetId}->getDocsAsHash();
	my %commonObsValues;
	foreach my $docId (keys %$docs) {
	    $statsDataset{$datasetId}->{$docId} = docStats($docs->{$docId}, $obsType, $logger);
	    addToMetaStats(\%meta, $statsDataset{$datasetId}->{$docId});

	    # common obs values
	    my $docObservs = $docs->{$docId}->getObservations($obsType);
	    my $total = $docs->{$docId}->getNbObsTotal($obsType);
	    foreach my $obs (keys %commonObs) {
		push(@{$commonObsValues{$obs}}, $docObservs->{$obs} / $total );
	    }
	}
	$metaStatsDataset{$datasetId} = aggregate(\%meta, \%commonObsValues);
    }
  
    globalCommonSummary(\%metaStatsDataset, \%commonObs);
    foreach my $datasetId (keys %$data) {
	print "\n\n**** $obsType, dataset '$datasetId'\n";
	datasetSummary($statsDataset{$datasetId}, $metaStatsDataset{$datasetId});
   }
    
}



sub docStats {
    my ($docProv, $obsType, $logger) = @_;

    my %stats;
    $stats{totalDistinctRatioHappax} = [ $docProv->getNbObsTotal($obsType) , $docProv->getNbObsDistinct($obsType),  $docProv->getNbObsDistinct($obsType) / $docProv->getNbObsTotal($obsType), undef ];
    my $doc = $docProv->getObservations($obsType);
    $stats{distribs} = obsDistribByRelFreq($doc, $stats{totalDistinctRatioHappax}->[0], 1, $logger); # highest first
    $stats{quantValuesCumul} = distribQuantiles($stats{distribs}->[1], \@printDistribQuantileLimits, 1, $logger);
    $stats{nbByFreq} = freqBins($doc, $logger);
    $stats{totalDistinctRatioHappax}->[3] = $stats{nbByFreq}->{1} / $stats{totalDistinctRatioHappax}->[0]; # happax 


    return \%stats;
}


sub addToMetaStats {
    my ($meta, $docStats) = @_;

    for (my  $i=0; $i<4; $i++) {
	push(@{$meta->{totalDistinctRatioHappax}->[$i]}, $docStats->{totalDistinctRatioHappax}->[$i]);
    }
    for (my $i=0; $i<scalar(@printDistribQuantileLimits); $i++) {
	push(@{$meta->{quantValuesCumul}->[$i]}, $docStats->{quantValuesCumul}->[$i]);
    }
    my ($bin, $binFreq);
    while (($bin, $binFreq) = each %{$docStats->{nbByFreq}}) {
	push(@{$meta->{nbByFreq}->{$bin}}, $binFreq);
    }
}


sub aggregate {
    my ($metaValues, $commonObsValues) = @_;

    my %res;
    foreach my $aggregType ("min", "Q1", "median", "Q3", "max") {
	for (my  $i=0; $i<4; $i++) {
	    $res{$aggregType}->{totalDistinctRatioHappax}->[$i] = aggregateVector($metaValues->{totalDistinctRatioHappax}->[$i], $aggregType);
	}
	for (my $i=0; $i<scalar(@printDistribQuantileLimits); $i++) {
	    $res{$aggregType}->{quantValuesCumul}->[$i] = aggregateVector($metaValues->{quantValuesCumul}->[$i], $aggregType);
	}
	my ($bin, $binFreq);
	while (($bin, $binFreq) = each %{$metaValues->{nbByFreq}}) {
	    $res{$aggregType}->{nbByFreq}->{$bin} = aggregateVector($metaValues->{nbByFreq}->{$bin}, $aggregType);
	}
	my ($obs, $values);
	while (($obs, $values) = each %$commonObsValues) {
	    $res{$aggregType}->{commonObs}->{$obs} = aggregateVector($commonObsValues->{$obs}, $aggregType);
	}
    }
    return \%res;
}


#
sub datasetSummary {

    my ($stats, $meta) = @_;
    
    if ($printDocDetails || $printStatSummary) {
	print "\n** Distribution\n";
	printf("%20.20s | %9.9s  %9.9s  %7.7s  %7.7s |", "dataset", "total", "distinct", "ratio", "hapax");
	for (my $i=0; $i<scalar(@printDistribQuantileLimits); $i++) {
	    printf("\t%7.3f", $printDistribQuantileLimits[$i]);
	}
	if ($printDocDetails) {
	    print "\n".("-" x (64+8*scalar(@printDistribQuantileLimits)))."\n";
	    foreach my $docId (sort keys %$stats) {
		printf("%20.20s | %9.9s  %9.9s  %6.2f%%  %6.2f%% |", $docId, $stats->{$docId}->{totalDistinctRatioHappax}->[0], $stats->{$docId}->{totalDistinctRatioHappax}->[1],  $stats->{$docId}->{totalDistinctRatioHappax}->[2], $stats->{$docId}->{totalDistinctRatioHappax}->[3]);
		for (my $i=0; $i<scalar(@printDistribQuantileLimits); $i++) {
		printf("\t%7.5f", $stats->{$docId}->{quantValuesCumul}->[$i]);
		}
		print "\n";
	    }
	}
	if ($printStatSummary) {
	    print "".("-" x (64+8*scalar(@printDistribQuantileLimits)))."\n";
	    foreach my $aggregType ("min", "Q1", "median", "Q3", "max") {
		printf("%20.20s | %9.9s  %9.9s  %6.2f%%  %6.2f%% |", $aggregType, $meta->{$aggregType}->{totalDistinctRatioHappax}->[0], $meta->{$aggregType}->{totalDistinctRatioHappax}->[1], $meta->{$aggregType}->{totalDistinctRatioHappax}->[2], $meta->{$aggregType}->{totalDistinctRatioHappax}->[3] );
		for (my $i=0; $i<scalar(@printDistribQuantileLimits); $i++) {
		    printf("\t%7.5f", $meta->{$aggregType}->{quantValuesCumul}->[$i]);
		}
		print "\n";
	    }
	}
    }

    print "\n** Most common observations\n";

    printf("%7.7s","rank");
    foreach my $docId (keys %$stats) {
	printf("\t%20.20s", $docId);
    }
    print "\n".("-" x (10+20*scalar(keys %$stats)))."\n";
    for (my $i=0;  $i<$printNbCommonObs; $i++) {
#    for (my $i=0;  ($i < scalar(@{$stats->{$docId}->{distribs}->[0]})) && ($i<$printNbCommonObs); $i++) {
	printf("%7.7s", $i+1);
	foreach my $docId (keys %$stats) {
	    if ($printRelFreqMostCommon) {
		printf("\t%10.10s (%7.5f)", $stats->{$docId}->{distribs}->[0]->[$i], $stats->{$docId}->{distribs}->[1]->[$i]);
	    } else {
		printf("\t%20.20s", $stats->{$docId}->{distribs}->[0]->[$i]);
	    }
	    
	}
	print "\n";
    }
    print "\n";


}


sub globalCommonSummary {
    my ($stats, $commonObs) = @_;

    print "\n** Common observations global\n";

    printf("%20.20s   %7.7s | ","observation", "stat");
    foreach my $datasetId (keys %$stats) {
	printf("%20.20s | ", $datasetId);
    }
    print "\n".("-" x 31)."|".(("-" x 22)."|" x scalar(keys %$stats))."\n";
    foreach my $obs (keys %$commonObs) {
	foreach my $aggregType ("min", "Q1", "median", "Q3", "max") {
	    printf("%20.20s   %7.7s | ", "$obs", "$aggregType");
	    foreach my $datasetId (keys %$stats) {
		printf("%20.7f | ", $stats->{$datasetId}->{$aggregType}->{commonObs}->{$obs}) ;
	    }
	    print "\n";
	}
	print "".("-" x 31)."|".(("-" x 22)."|" x scalar(keys %$stats))."\n";
    }
    
}



# PARSING OPTIONS
my %opt;
getopts('ihl:L:t:r:s:m:p:f', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
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
my $force=$opt{f};
$summaryOptions = $opt{o} if ($opt{o});

my @summaryParts = split(":",$summaryOptions);

@printDistribQuantileLimits = split(",", $summaryParts[0]);
$printDistribHighestFirst = $summaryParts[1];
$printCumulDistrib = $summaryParts[2];
$printNbCommonObs = $summaryParts[3];


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
$params{formatting} = defined($formattingSeparator) ? $formattingSeparator : 0;
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
my %globalCountDocProv;
my %docFreqCountDocProv;
foreach my $dataset (keys %$datasets) {
    $datasets->{$dataset}->populateAll();
    my $path = $mapIdToPath{$dataset};
    if (-f $path) { # list file
	$path  = dirname($path);
    }
    $globalCountDocProv{$dataset} = $datasets->{$dataset}->getGlobalCountDocProv() ;
    $docFreqCountDocProv{$dataset} =  $datasets->{$dataset}->getDocFreqCountDocProv() ;

}



# -----------------------------------------------------------------------------------
# THIS IS WHERE THE PROFILE ANALYSIS STARTS





foreach my $obsType (@obsTypes) {
    globalSummary($datasets, $obsType, \%globalCountDocProv, \%docFreqCountDocProv, $logger);
}
