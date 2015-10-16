#!/usr/bin/perl



use strict;
use warnings;
use Getopt::Std;
use Carp;
use CLGTextTools::ObsCollection;
use CLGTextTools::Commons qw/readConfigFile/;

my $progName="load-ngrams-counts.pl";
my $colCountFile=1; # 1 = abosulte freq, 2 = relative freq
my $useCountFile;

sub usage {
	my $fh = shift;
	$fh = *STDOUT if (!defined $fh);
	print $fh "Usage: $progName [options] <config file> <doc1> [<doc2> [...] ]\n";
	print $fh "\n";
	print $fh " TODO\n";
	print $fh "\n";
	print $fh "   Options:\n";
	print $fh "     -h print this help\n";
	print $fh "     -c use observations count files instead of extracting observations from raw text\n";
	print $fh "        files. The count file corresponding to observation type <obs> for document <doc>\n";
	print $fh "        is read from <doc>.<obs>.count\n";
	print $fh "\n";
}



sub checkParam {
    my ($param, $config, $configFile) = @_;
    die "$progName: error, parameter '$param' not defined in config file '$configFile'" if (!defined($config->{$param}) || ($config->{$param} eq ""));
}


sub readCountFile {
    my $f = shift;

    open(COUNT, "<:encoding(utf-8)", $f) or die "$progName error: cannot open '$f'";
    my %content;
    while (<COUNT>) {
        chomp;
        my @cols = split(/\t/, $_);
        die "$progName error: expecting exactly 3 columns in $f but found ".scalar(@cols).": $!" if (scalar(@cols) != 3);
        $content{$cols[0]} = $cols[$colCountFile];
    }
    close(COUNT);
    return \%content;
}





sub readDocDataWrapper {
    my ($docFile, $obsTypesList, $config, $configFile) = @_;

    my $data = {};
    if ($useCountFile) {
	foreach my $obsType (@$obsTypesList) { # loading all data
	    $data->{$obsType} = readCountFile("$docFile.$obsType.count");
	}
    } else {
	checkParam("minFreqObsIndiv", $config, $configFile);
	checkParam("performWordTokenization", $config, $configFile);
	checkParam("InputSegmentationFormat", $config, $configFile);
	# optional, so no check
	#checkParam("wordObsVocabResources", $config, $configFile);
	my %params;
	$params{obsTypes} = $obsTypesList;
	$params{wordTokenization} = $config->{performWordTokenization};
	$params{formatting} = $config->{InputSegmentationFormat};
	$params{wordVocab} = $config->{wordObsVocabResources}; # optional, might be undef
	$data = extractObservsWrapper(\%params, $docFile, $config->{minFreqObsIndiv}, 0);
    }
    return $data;
}





# PARSING OPTIONS
my %opt;
getopts('hc', \%opt ) or  ( print STDERR "Error in options" &&  usage(*STDERR) && exit 1);
usage($STDOUT) && exit 0 if $opt{h};
print STDERR "at least 2 arguments expected but ".scalar(@ARGV)." found: ".join(" ; ", @ARGV)  && usage(*STDERR) && exit 1 if (scalar(@ARGV) < 2);
$useCountFile = $opt{c};

my $configFile=shift(@ARGV);
my @docs=@ARGV;

my $config = readConfigFile($configFile);

checkParam("obsTypesList", $config, $configFile);
my @obsTypesList = split(":", $config->{"obsTypesList"});
#print STDERR "DEBUG $progName: ".join(";",@obsTypesList)."\n";



my @docsData;
foreach my $doc (@docs) {
    push(@docsData, readDocDataWrapper($doc, \@obsTypesList, $config, $configFile));
}

