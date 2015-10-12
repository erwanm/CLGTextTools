package Text::TextAnalytics;

use warnings;
use strict;
use Carp;
use Log::Log4perl;
use Text::TextAnalytics::SegmentReader::DirSegmentReader;
use Text::TextAnalytics::SegmentReader::FileSegmentReader;
use Text::TextAnalytics::SegmentReader::ListSegmentReader;

use base 'Exporter';
our @EXPORT_OK = qw/
	@possibleLogLevels $prefixModuleMeasure $prefixModuleTokenizer $prefixModuleNGrams $prefixModuleSegmentReader $prefixModuleScoresConsumer
	$prefixModuleHighLevelComparator genericObjectBuilder parseObjectDescription getParametersStringGeneric parseParametersFile readNGramsFile $indexedNGramClassName/;




our $VERSION = '0.3.1';

our @possibleLogLevels = qw/TRACE DEBUG INFO WARN ERROR FATAL OFF/;
our $prefixModuleMeasure = "Text::TextAnalytics::Measure::";
our $prefixModuleTokenizer = "Text::TextAnalytics::Tokenizer::";
our $prefixModuleNGrams = "Text::TextAnalytics::NGrams::";
our $prefixModuleSegmentReader = "Text::TextAnalytics::SegmentReader::";
our $prefixModuleHighLevelComparator = "Text::TextAnalytics::HighLevelComparator::";
our $prefixModuleScoresConsumer = "Text::TextAnalytics::ScoresConsumer::";


our $defaultScoresFileName = "scores.txt";
our $defaultHLComparatorDescr = "StdHLComparator;minNGrams=1;verbose=1";
our $defaultMeasureDescr = "OriginalChiSquare;averageByNumberOfNGrams=1;incNumberOfNGrams=1";
our $scoresWriterClassName = "ScoresWriterConsumer";
our $rankerClassName = "RankingScoresConsumer";
our $defaultScoresWriterDescr = "$scoresWriterClassName;filename=$defaultScoresFileName";
our $defaultScoresRankerDescr = "$rankerClassName";
our $defaultConsumerDescrList = "$defaultScoresWriterDescr";

our %defaultTokenizerDescrs = (
					"word" => "BasicWordTokenizer;toLowercase=1;detachPunctuationOldVersion=1",
					"char" => "CharTokenizer;toLowercase=1;glueWords=1"
							);
our $defaultTokenizerDescr = $defaultTokenizerDescrs{"word"};
our %defaultNGramsDescrs = (
					"word;bag" => "HashByGramIndexedBagOfNGrams;n=1",
					"char;bag" => "CharsBagOfNGrams;n=1",
					"word;seq" => "HashByGramIndexedSequenceOfNGrams;n=1",
					"char;seq" => "CharsSequenceOfNGrams;n=1"
							);
our $defaultNGramsDescr = $defaultNGramsDescrs{"word;bag"};

our $indexedNGramClassName = "Text::TextAnalytics::NGrams::IndexedNGrams";

# global variable to avoid spending time in genericObjectBuilder (eval "require ...")
my %loadedLibraries;


=head1 NAME

Text::TextAnalytics - This module provides some generic subroutines (not a class)

=head1 VERSION

Version 0.3.1.dev


=head1 DESCRIPTION


=head2 parseParametersFile($optHashRef, $optName)

Given a hash ref $optHashRef representing the options as parsed by getopts, parses a parameter file specified given the option name $optName.

=cut


sub parseParametersFile {
	my $optHashRef = shift;
	my $optName = shift;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	# parse parameters from file
	if (defined($optHashRef->{$optName})) {
		open(PARAMS, "<", $optHashRef->{$optName}) or $logger->logconfess("can not open parameters file ".$optHashRef->{$optName});
		while (my $line = <PARAMS>) {
			$line =~ s/#.*$//; # remove comments
			if ($line =~ m/\S/) { # line is not empty
				my ($name, $value) = ($line =~ m/^-(.)\s*(.*)$/);
				if (defined($name) && defined($value)) {
					$optHashRef->{$name} = $value;
				} else {
					$logger->logconfess("Syntax error in parameters file ".$optHashRef->{$optName}." in line '$line'");
				}
			}
		}
		close(PARAMS);
	}
}

=head2 convenientReader($descr, $readAs)

$descr is 'name[:startNo-endNo]'
creates a SegmentReader object which will read 'name' either as a file (segments are lines), a directory (segments are files in the directory) 
or a list of files (segments are files in the list) depending  on $readAs (possible values: file, dir, list)

=cut

sub convenientReader {
	my $name = shift;
	my $readAs= shift;
	my $multiRange=undef;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	if ($name =~ /:/) {
		($name, $multiRange) = ($name =~ m/^([^:]+):(.+)$/);
	}
	$logger->debug("init reader: type=$readAs, name='$name', multiRange=".($multiRange?$multiRange:"undefined"));
	if ($readAs eq "file") {
		return Text::TextAnalytics::SegmentReader::FileSegmentReader->new({ filename => $name, multiRange => $multiRange } );
	} elsif ($readAs eq "dir") {
		return Text::TextAnalytics::SegmentReader::DirSegmentReader->new({ dirname => $name, multiRange => $multiRange } );
	} elsif ($readAs eq "list") {
		return Text::TextAnalytics::SegmentReader::ListSegmentReader->new({ filename => $name, multiRange => $multiRange } ); 
	} elsif ($readAs eq "none") {
		return $name;
	} else {
		$logger->logconfess("Invalid reader type '$readAs' (name '$name')");
	}
}




=head2 parseMultiParameter($string)

parses a string like "myAttr1=myVal1;myAttr2=myVal2;...." and returns a hash ref with these pairs

=cut

sub parseMultiParameter {
	my $input= shift;
	my %res;
	my @pairs = split(/;/, $input);
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	foreach my $pair (@pairs) {
		my ($name, $val) = split(/=/, $pair);
		$logger->logconfess("wrong parameter in '$input': a list 'myAttr1=myVal1;myAttr2=myVal2;....' is expected.") if (!defined($name) || !defined($val));
		$res{$name} = $val;
	}
	return \%res; 
}



=head2 parseObjectDescription($description)

given a description with format 'myClassName[;myParamName1=myParamValue1;...]',
returns ($myClassName, $myParams) where $myParams is a hash corresponding to the parameters supplied (possibly undef).

=cut

sub parseObjectDescription {
	my $description = shift;
	my $classname;
	my $params;
	if ($description =~ /;/) {
		my $paramsList;
#		($classname,@paramsList) = split(/;/, $description);
#		$params = parseMultiParameter(join(";", @paramsList));
		($classname,$paramsList) = ($description =~ m/^([^;]+);(.*)$/);
		$params = parseMultiParameter($paramsList);
	} else {
		$classname = $description;
	}
	return ($classname, $params);
}


=head2 genericObjectBuilder($className, $params, $optionalPrefix)

returns a new instance of class $className by calling this class 'new' method with $params as parameter.
If $optionalPrefix is supplied, then both names are tried.
fails if $className is unknown (class not found).
Can be used in the following way:
genericObjectBuilder(parseObjectDescription($stringDescription))

=cut

sub genericObjectBuilder {
	my $className = shift;
	my $params = shift;
	my $optionalPrefix = shift;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	$logger->debug("Building object '$className': looking for library.") if ($logger->is_debug());
#	eval "use $className; 1" or $logger->logconfess("Unknown class: '$className' when trying to create object"); # old version
	if (!defined($loadedLibraries{$className})) {
		$logger->debug("looking for '$className'; loadedLibraries=".join(" ",keys %loadedLibraries)) if ($logger->is_debug());
		if (!eval("require $className;1")) {
			my $className2 = $className;
			if (defined($optionalPrefix)) {
				$className2 = $optionalPrefix.$className;
				$logger->debug("Object $className not found, trying $className2.");
			}
			eval("require $className2;1") or $logger->logconfess("Unknown class '$className' ".(defined($optionalPrefix)?"(and no class '$className2' either) ":"")."when trying to create object");
			$loadedLibraries{$className} = $className2;
			$logger->debug("Class $className loaded as $className2");
		} else {
			$loadedLibraries{$className} = $className;
			$logger->debug("Class $className loaded");
		}
	}
	$className = $loadedLibraries{$className};
	$logger->debug("Calling constructor with parameters: [".join("; ", map { defined($params->{$_})?"$_=$params->{$_}":"undef" } keys %$params)."]") if ($logger->is_debug());
	my $res = $className->new($params);
	$logger->debug("Object $className succesfully initialized.");
	return $res; 	
}


=head2 getParametersStringGeneric($object, $variables, $prefix, $noheader)

generic sub to generate a description of the parameters used in an object. $variables is a list ref containing the parameters to include.

=cut

sub getParametersStringGeneric {
	my ($object, $variables, $prefix, $noheader) = @_;
	$prefix="" if (!defined($prefix));
	my $str = "";
	$str .= $prefix."Parameters for the ".ref($object)." object:\n" unless ($noheader);
	foreach my $param (@$variables) {
		$str .= $prefix."$param=".(defined($object->{$param})?$object->{$param}:"undef")."\n";
	}
	return $str;
}

=head2 createDefaultLogConfig($filename, $logLevel)

creates a simple log configuration for log4perl, usable with Log::Log4perl->init($config)

=cut

sub createDefaultLogConfig {
	my ($filename, $logLevel) = @_;
	my $config = qq(
   		log4perl.rootLogger              = $logLevel, LOG1
   		log4perl.rootLogger.Threshold = OFF
   		log4perl.appender.LOG1           = Log::Log4perl::Appender::File
   		log4perl.appender.LOG1.filename  = $filename
   		log4perl.appender.LOG1.mode      = write
   		log4perl.appender.LOG1.utf8      = 1
   		log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
   		log4perl.appender.LOG1.layout.ConversionPattern = [%r] %d %p %m\t in %M (%F %L)%n
	);
	return \$config;
}

=head2 initLog($logConfigFileOrLevel, $logFilename)

initializes a log4perl object in the following way: if $logConfigFileOrLevel is a log level, then uses the
default config (directed to $logFilename), otherwise $logConfigFileOrLevel is supposed to be the log4perl
config file to be used.

=cut

sub initLog {
	my ($logConfigFileOrLevel, $logFilename) = @_;
  	my $logLevel = undef;
#  	if (defined($logParam)) {
	if (grep(/^$logConfigFileOrLevel/, @possibleLogLevels)) {
		Log::Log4perl->init(createDefaultLogConfig($logFilename, $logConfigFileOrLevel));
	} else {
		Log::Log4perl->init($logConfigFileOrLevel);
	}
}


=head2 readNGramsFile($filename, $containsKey, $bagOfNGramDescrOrUndef, $sharedIndexedNGramOrUndef, $onlyUpdateIndex, $nbSegmentsHashRefOrUndef)

reads an ngram file $filename (as written by CountNGramsHLComparator) and creates a BagOfNGrams object corresponding to description $bagOfNGramDescrOrUndef containing the same values. 
if $nbSegmentsOrUndef is defined (must be a hash ref), adds the number of segments containing each ngram to this hash. The only case where $bagOfNGramDescrOrUndef can be undefined
is if both $sharedIndexedNGramOrUndef and $onlyUpdateIndex are defined/true (see below).

$containsKey indicates whether there is a key column, but keys are not used anyway: no guarantee at all that a given ngram will be assigned the same key.

if defined, $sharedIndexedNGramOrUndef is an indexed NGram object with which the index will be shared.  

if $onlyUpdateIndex is true, then the values (frequencies) are not set in the object, only the index (keys) is created/updated (depends on $sharedIndexedNGramOrUndef). 
If the object is actually not an IndexedNGram, then there is nothing to do.

Remark: the N value (size of ngrams) does not have to be specified in $bagOfNGramDescr (will be overriden)

returns ($nGramsObject, $nbSegments)

Note to myself: this method is badly designed (parameters etc.), and has not been thoroughly tested.

TODO currently nothing is checked about the fact that the data loaded from the file is the same/differs from the one loaded as reference (because this case must be possible) 

=cut

sub readNGramsFile {
	my ($filename, $containsKey, $bagOfNGramDescrOrUndef, $sharedIndexedNGramOrUndef, $onlyUpdateIndex, $nbSegmentsHashRefOrUndef) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	$logger->debug("init reading ngrams from file: filename=$filename, containsKey=$containsKey, onlyUpdateIndex=$onlyUpdateIndex");
	open(FILE, "<:encoding(utf-8)", $filename) or $logger->logconfess("can not open ngrams file $filename");
	my $lineNo = 1;
	my ($n, $totalCount, $nbSegments);
	while (<FILE>) { # step 1: find the first non commented line (header line)
		if (!m/^#/) {
			chomp;
			($n, $totalCount, $nbSegments) = split;
			$logger->logconfess("Invalid format in '$filename' for header line (line $lineNo): '$_'") if (!defined($n) || !defined($totalCount) || !defined($nbSegments));
			$logger->debug("Reading header line $lineNo: n=$n, totalCount=$totalCount, nbSegments=$nbSegments");
			last;
		}
		$lineNo++; 
	}
	$logger->logconfess("Invalid format in '$filename': EOF before finding header line (line $lineNo)") if (!defined($n));
	my $ngrams;
	if (defined($bagOfNGramDescrOrUndef)) {
		$logger->debug("Creating the new ngrams collection object");
		my ($className, $classParams) = parseObjectDescription($bagOfNGramDescrOrUndef);
		$ngrams = genericObjectBuilder($className, { n => $n, shared => $sharedIndexedNGramOrUndef, %$classParams }, $Text::TextAnalytics::prefixModuleNGrams);
	} else {
		$logger->debug("Checking that the index of the NGrams object supplied can be updated");
		if (defined($sharedIndexedNGramOrUndef) && $onlyUpdateIndex && $sharedIndexedNGramOrUndef->isa($indexedNGramClassName)) {
			$ngrams = $sharedIndexedNGramOrUndef;
		} else {
			$logger->logconfess("something is wrong with parameters: bagOfNGramDescrOrUndef is undef but the other parameters do no fulfill the conditions for that.");
		}
	}
	my $isIndexed = $ngrams->isa($indexedNGramClassName);
	$logger->debug("Reading data...");
	while (<FILE>) {
		if (!m/^#/) {
			chomp;
			my ($nbOccs, $nbSegs, $key, $ngramStr);
			if ($containsKey) {
				($nbOccs, $nbSegs, $key, $ngramStr) = ( m/^(\d+)\t(\d+)\t(\W+)\t(.*)$/);
			} else {
				($nbOccs, $nbSegs, $ngramStr) = ( m/^(\d+)\t(\d+)\t(.*)$/);
			}
			$key = undef; # old key never used
			if (length($ngramStr) == $n) { # Char NGram
				if ($onlyUpdateIndex) {
					$key = $ngrams->getKey($ngramStr);
					if ($isIndexed && !defined($key)) {
						$key = $ngrams->createKey($ngramStr);
						$logger->debug("Creating new key $key for ngram '$ngramStr'");
					}
				} else {
					$key = $ngrams->setValue($ngramStr, $nbOccs);
					$logger->debug("Setting value $nbOccs for ngram '$ngramStr' (key $key)");
				}
			} else {
				my @ngram = split(/\t/, $ngramStr);
				if (scalar(@ngram) == $n) {
					if ($onlyUpdateIndex) {
						$key = $ngrams->getKey(\@ngram);
						if ($isIndexed && !defined($key)) {
							$key = $ngrams->createKey(\@ngram);
							$logger->debug("Creating new key $key for ngram '".join("|", @ngram)."'");
						}
					} else {
						$key = $ngrams->setValue(\@ngram, $nbOccs);
						$logger->debug("Setting value $nbOccs for ngram '".join("|", @ngram)."' (key $key)");
					}
				} else {
					$logger->logwarn("Parsing error in $filename line $lineNo: ngram is '".join("|", @ngram)."' (tabulations in grams?)");
					$totalCount -= $nbOccs;
					$key =undef;
				}
			}
			$logger->debug("Setting nb segments to $nbSegs for key $key");
			$nbSegmentsHashRefOrUndef->{$key} = $nbSegs if (defined($nbSegmentsHashRefOrUndef) && defined($key));
		}
		$lineNo++;
	}
	$ngrams->setTotalCount($totalCount) if (!$onlyUpdateIndex);
	return ($ngrams, $nbSegments);	
	close(FILE);
	
}


1; # End of Text::TextAnalytics
