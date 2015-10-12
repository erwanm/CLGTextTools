package Text::TextAnalytics::HighLevelComparator::StdHLComparator;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::HighLevelComparator::HighLevelComparator;
use  Text::TextAnalytics::Tokenizer::Tokenizer qw/$defaultFrontierChar/;
use Text::TextAnalytics qw/$prefixModuleMeasure $prefixModuleTokenizer $prefixModuleNGrams $prefixModuleSegmentReader $prefixModuleScoresConsumer
		genericObjectBuilder parseObjectDescription/;
use Scalar::Util 'blessed';

our @ISA = qw/Text::TextAnalytics::HighLevelComparator::HighLevelComparator/;
our $VERSION = $Text::TextAnalytics::VERSION;

# TODO pbm ids as filenames ("R", "P" for measure)

=head1 NAME

Text::TextAnalytics::HighLevelComparator::StdHLComparator -  class for high level text comparison

ISA = Text::TextAnalytics::HighLevelComparator::HighLevelComparator


=cut



my %defaultOptions = (  
					   "singleRefData" => 0,
					   "loadProbeFirst" => 0, 
					   "addTokensFrontiers" => 0,
					   "minTokens" => 0,
					   "minNGrams" => 0,
					   "removeNGramsWithFreqLessThan" => 0,
					   "verbose" => 1, 
					   "information" => ""
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
my @parametersVars = (
					   "singleRefData",
					   "loadProbeFirst",
					   "addTokensFrontiers", 
					   "minTokens", 
   					   "minNGrams",
   					   "removeNGramsWithFreqLessThan",
					   "verbose", 
					  );


my $bagOfNGramsClassName = "Text::TextAnalytics::NGrams::BagOfNGrams";

=head1 DESCRIPTION

=head2 new($class, $params)

$params is an hash ref which optionally defines the following parameters: 

=over 2

=item * singleRefData: boolean; indicates whether the segments read from the reference data should be gathered in only one
NGrams data structure (in other words consider the ref data as one big segment). note that (in general) this is 
different from concatenating the segments: there can not be any ngram which overlap two different segments. this option
makes the computation a lot faster, but the results are very different.  

=item * loadProbeFirst: boolean. if true the probe data is loaded first, which means that it is the one which is totally stored in memory (thus it
can be used when the ref data is very big compared to the probe data). Warning: this option prevents using the singleRefData option (since the ref
data is never completely loaded in memory), and also prevents using a measure which requires segment count by ngrams (but it should be possible to 
load such data independtly). 

=item *  addTokensFrontiers: boolean. adds "frontiers" at the beginning and end of every segment, e.g. if n=2 (ab, bc, cd) becomes (#a, ab, bc, cd, d#). 

=item *  minTokens: integer, minimum number of tokens for the segment to be taken into account

=item *  minNGrams: integer, minimum number of ngrams - after preprocessing - for the segment to be taken into account

=item * removeNGramsWithFreqLessThan: minimum frequency for an ngram to be taken into account.

=item * verbose: boolean. if 0, nothing is printed to stdout.

=item * information: string

=back

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{logger}->logconfess("Incompatible options: singleRefData can not be used if loadProbeFirst is set.") if ($self->{loadProbeFirst} && $self->{singleRefData});
	$self->{logger}->logconfess("Option loadProbeFirst is not compatible with a measure which requires segment counts by ngram (method requiresSegmentsCountByNGram())") if ($self->{loadProbeFirst} && $self->{measure}->requiresSegmentsCountByNGram());
	for my $probeOrRef  ("probe", "ref" ) {
		$self->{logger}->logconfess("Option 'removeNGramsWithFreqLessThan' is not compatible with a SequenceOfNGrams object, only BagOfNGrams") if ($self->{removeNGramsWithFreqLessThan} && !genericObjectBuilder($self->{$probeOrRef."NGramsClassName"}, $self->{$probeOrRef."NGramsParams"},$Text::TextAnalytics::prefixModuleNGrams)->isa($bagOfNGramsClassName) );
	}
	return $self; 	
}



=head2 getParametersString($prefix)

see parent documentation

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
    my $str = $self->SUPER::getParametersString($prefix);
	$str .= $prefix."Reference reader parameters:\n".$self->{refReader}->getParametersString($prefix."  ") if (defined($self->{refReader}));
	$str .= $prefix."Probe reader parameters:\n".$self->{probeReader}->getParametersString($prefix."  ") if (defined($self->{refReader}));
    $str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix,1);
	return $str;
}


=head2 compare($refReader, $probeReader)

see parent documentation

params: probe and ref reader, as objects or as descriptions
=cut

sub compare {
	my $self = shift;
	my $refReaderParam = shift;
	my $probeReaderParam = shift;
	$self->{logger}->logconfess("Error: probe and/or reference reader parameters must be defined.") if (!defined($probeReaderParam));
	$self->{probeReader} = ref($probeReaderParam)?$probeReaderParam:genericObjectBuilder(parseObjectDescription($probeReaderParam), $Text::TextAnalytics::prefixModuleSegmentReader);
	$self->{refReader} = ref($refReaderParam)?$refReaderParam:genericObjectBuilder(parseObjectDescription($refReaderParam), $Text::TextAnalytics::prefixModuleSegmentReader);
	
	my ($firstDataStr, $firstDataReader, $sndDataStr, $sndDataReader) = ("reference", $self->{refReader}, "probe", $self->{probeReader});
	($firstDataStr, $firstDataReader, $sndDataStr, $sndDataReader) = ("probe", $self->{probeReader}, "reference", $self->{refReader}) if ($self->{loadProbeFirst});
	$self->{firstDataStr} = $firstDataStr;
	my $startDate = localtime();
	my $startTimeS = time();
	$self->{logger}->logconfess("probeReader and refReader must be defined.") if (!defined($self->{probeReader}) || !defined($self->{refReader}));
	my $info = "Started $startDate (v. $VERSION)\n";
	print $info if ($self->{verbose});
	$self->{information} .= "# $info";
	$info = "Reading $firstDataStr data";
	print "$info...\n" if ($self->{verbose});
	$self->{logger}->info($info);	
	my $segmentsCountByNGram = $self->{measure}->requiresSegmentsCountByNGram()?{}:undef;
	my $nbSegmentsProcessed;
	($self->{firstDataNGrams}, $nbSegmentsProcessed) = $self->loadSegmentsAsNGrams( $firstDataReader, $self->{singleRefData}, $segmentsCountByNGram, "ref");
	$self->{measure}->setSegmentsCountByNGram($nbSegmentsProcessed, $segmentsCountByNGram, $self->{singleRefData}?$self->{firstDataNGrams}:$self->getAnyNGramFromHash($self->{firstDataNGrams}));
	print "\n" if ($self->{verbose});
#	$self->printDebugFirstData() if ($self->{logger}->is_debug());
	my $afterLoadingRefDate = localtime();
	$self->{information} .= "# Date after loading $firstDataStr data: $afterLoadingRefDate\n";
	$self->{information} .= $self->getParametersString("# ");
	$self->initializeConsumers($self->{information});
	$info = "Reading $sndDataStr segments and comparing ngrams using ".$self->{measure}->getName()."...";
	print "$info\n"  if ($self->{verbose});
	$self->{logger}->info($info);
	$self->readSegmentsAndCompareNGrams($sndDataReader, $self->{firstDataNGrams});
	my $endDate = localtime();
	my $endTimeS = time();
	$self->{information} .= "# ended $endDate\n";
	$info  = sprintf("Time elapsed: %d seconds\n",($endTimeS-$startTimeS));
	print "$info"  if ($self->{verbose});
	$self->{information} .= "# $info";
	$self->finalizeConsumers($self->{information});
}



=head2 loadSegmentsAsNGrams($reader, $allSegmentsInOneNGram, $countNGramsBySegment, $probeOrRef)

reads the segments provided by the SegmentReader object and returns an array of NGrams objects or a single NGram object (option $allSegmentsInOneNGram).
 in the array some slots might be empty if there are empty lines.
 
$countNGramsBySegment is a hash ref which must be set if for every ngram the number of occurrences by segment is needed (e.g. for IDF). Otherwise it can be left undefined.
If the counts are only obtained from this data it should be the empty hash {}, but it can also be a previous hash of counts which will be completed using this data (warning: keys must be compatible! not sure this is possible currently!) 

$probeOrRef = "probe" or "ref" (for NGrams object)

=cut

sub loadSegmentsAsNGrams {
	my ($self, $reader, $allSegmentsInOneNGram, $segmentsCountByNGram, $probeOrRef) = @_;
	$self->{logger}->info("Starting reading segments");
	my $nbTokens = 0;
	my $nbSkipped = 0;
	my $globalNGrams = genericObjectBuilder($self->{$probeOrRef."NGramsClassName"}, $self->{$probeOrRef."NGramsParams"},$Text::TextAnalytics::prefixModuleNGrams); # for case single NGram
	my %ngrams; 
    # Note that segments can be skipped because of the minimum number of ngrams/tokens condition;
    # this case should not be confused with the segments which are "skipped" because of the "startAt/endAt" condition, which is applied
    # in the SegmentReader object -> these two cases are different: the SegmentReader does not know about the first condition and conversely
    # this sub does not know about the second condition.
	while (defined(my $data = $reader->next())) {
		my $tokens = $self->preprocessPrettyPrintAndLog($reader, $data, $probeOrRef);
		if (defined($tokens)) {
			my $nbNGrams = 0;
			my $newNGrams = undef; # only for NOT $allSegmentsInOneNGram
			if ($allSegmentsInOneNGram) {  # 1.a) add ngrams to existing collection IF condition on minNGrams is satisfied   
				$nbNGrams = $globalNGrams->addTokens($tokens, $segmentsCountByNGram, $self->{minNGrams});
			} else { # 1.b) add ngrams to new collection IF condition on minNGrams is satisfied
				$newNGrams = genericObjectBuilder($self->{$probeOrRef."NGramsClassName"}, { shared => $globalNGrams, %{$self->{$probeOrRef."NGramsParams"}} }, $Text::TextAnalytics::prefixModuleNGrams); # NB: $globalNGrams is used as a dummy object to share index, actually it is always empty in this case
				$nbNGrams = $newNGrams->addTokens($tokens, $segmentsCountByNGram, $self->{minNGrams});
				$newNGrams->filterOutRareNGrams($self->{removeNGramsWithFreqLessThan}) if ($self->{removeNGramsWithFreqLessThan});
			}
			if ($nbNGrams > -1) { # 2) check if condition on minNGrams was satisfied. Warning: if there is no such condition, it is possible that an empty segment is added.
				$self->{logger}->debug("Adding tokens for segment no ".$self->{currentNbSegmentsRead}." (id ".$self->{currentId}.")");
				$nbTokens += $self->{tokenizer}->returnsList()?scalar(@$tokens):length($tokens);
				$ngrams{$self->{currentId}} = $newNGrams if (defined($newNGrams)); # Note: this condition is equivalent to !$allSegmentsInOneNGram
			} else {
				$self->{logger}->debug("Skipping segment no ".$self->{currentNbSegmentsRead}." (id ".$self->{currentId}."): not enough ngrams.");		
				$nbSkipped++;
			}
		} else {
			$nbSkipped++;
		}
	}
	my $nbSegmentsProcessed = $reader->getNbAlreadyRead()-$nbSkipped;
	my $info = "Loading ngrams: read $nbTokens tokens in ".$reader->getNbAlreadyRead()." segment (total), processed $nbSegmentsProcessed segments and skipped $nbSkipped segments.";
	$self->{information} .= "# $info\n";
	$self->{logger}->info($info);
	print "\n$info\n"  if ($self->{verbose});
	if ($allSegmentsInOneNGram) {
		$globalNGrams->filterOutRareNGrams($self->{removeNGramsWithFreqLessThan}) if ($self->{removeNGramsWithFreqLessThan});
		return ($globalNGrams, $nbSegmentsProcessed);
	} else {
		return (\%ngrams, $nbSegmentsProcessed);
	}
	
}



sub getAnyNGramFromHash {

	my $self = shift;
	my $hashRef =shift;
	my $res;
	if (scalar(keys %$hashRef) == 0) {
		$self->{logger}->logconfess("Hash is empty");
	} else {
		($_, $res) = each (%$hashRef);
		return $res;
	}
	
}


=head2 readSegmentsAndCompareNGrams($sndDataReader, $firstDataNGrams)

sub responsible for the comparison (must be called after reading the first data).

TODO WARNING: the ids must be unique, including the case where other datasets are compared in another part of the code!

=cut

sub readSegmentsAndCompareNGrams {
	my ($self, $reader, $firstDataNGrams) = @_;
	my $nbTokens=0;
	my $nbSkipped = 0;
	# if singleRefData, then we know that first data read was reference (otherwise error in sub new)
	my $aRefToSomeNGramObject = $self->usesSingleReferenceData()?$firstDataNGrams:$self->getAnyNGramFromHash($firstDataNGrams); # goal = find a ref to any NGrams object (so that new objects share the same index) (case single segment trivial, case multiple segments a bit harder)
	while (defined(my $data = $reader->next())) {
		my $tokens = $self->preprocessPrettyPrintAndLog($reader, $data, $self->{loadProbeFirst}?"ref":"probe");
		if (defined($tokens)) {
			my $nbTokensThis = ref($tokens)?scalar(@$tokens):length($tokens);
			$nbTokens += $nbTokensThis;
			 # NB: $globalNGrams is used as a dummy object to share index, actually it is always empty in this case
			my $ngrams = genericObjectBuilder($self->{probeNGramsClassName}, { shared => $aRefToSomeNGramObject, %{$self->{probeNGramsParams}} },$Text::TextAnalytics::prefixModuleNGrams);
			my $nbNGrams = $ngrams->addTokens($tokens, undef, $self->{minNGrams}); # remark: idf is not taken into account for the "probe" data (only for ref)
			$ngrams->filterOutRareNGrams($self->{removeNGramsWithFreqLessThan}) if ($self->{removeNGramsWithFreqLessThan});
			if ($nbNGrams > -1)  {  # check if condition on minNGrams was satisfied. Warning: if there is no such condition, it is possible that an empty segment is added.
				$self->{logger}->debug("Computing similarity for segment no ".$self->{currentNbSegmentsRead}." (id ".$self->{currentId}.")");		
				if ($self->usesSingleReferenceData()) {  # single ref collection (again, if condition is true then first data = ref (see above)
					my $score = $self->{measure}->score("P".$self->{currentId}, $ngrams, "R0", $firstDataNGrams); # WARNING: the ids must be unique, including the case where other datasets are compared in another part of the code!
					$self->sendScoresToConsumers($score, $self->{currentId}, undef);
				} else {                             # multiple ref collections
					foreach my $firstDataId (keys %$firstDataNGrams) {
						my ($probeId, $probeNGram, $refId, $refNGram) = $self->{loadProbeFirst}?($firstDataId, $firstDataNGrams->{$firstDataId}, $self->{currentId}, $ngrams):($self->{currentId}, $ngrams, $firstDataId, $firstDataNGrams->{$firstDataId});
						$self->{logger}->debug("Computing similarity: probe segment id $probeId against ref segment id $refId");		
						my $score = $self->{measure}->score("P".$probeId, $probeNGram, "R".$refId, $refNGram);
						$self->sendScoresToConsumers($score, $probeId, $refId);
					}
				}
			} else {
			# TODO getTotalCount wrong for MultiLevelNGrams
				$self->{logger}->debug("Skipping segment no ".$self->{currentNbSegmentsRead}." (id ".$self->{currentId}."): not enough ngrams (".$ngrams->getTotalCount().")");		
				$nbSkipped++;
			}
		} else {
			$self->{logger}->debug("Skipping segment no ".$self->{currentNbSegmentsRead}." (id ".$self->{currentId}."): not enough tokens.");		
			$nbSkipped++;
		}
	}
	my $nbSegmentsProcessed = $reader->getNbAlreadyRead()-$nbSkipped;
	my $info = "After comparison stage: read $nbTokens tokens in ".$reader->getNbAlreadyRead()." segment (total), processed $nbSegmentsProcessed segments and skipped $nbSkipped segments.";
	$self->{information} .= "# $info\n";
	$self->{logger}->info($info);
	print "\n$info\n"  if ($self->{verbose});
	return $nbSegmentsProcessed;
}





=head2 preprocessPrettyPrintAndLog($reader, $data, $probeOrRef)

prints the current line/id, runs the preprocessing step and writes debug information to log file if needed.
returns the tokens (as a string or a list depending on $self->{tokenizer}->returnsList())

$probeOrRef = "probe" or "ref", in order to use the right ngrams parameter for frontiers

=cut 

sub preprocessPrettyPrintAndLog {
	my ($self, $reader, $data, $probeOrRef) = @_;
	$self->{currentNbSegmentsRead} = $reader->getNbAlreadyRead();
	$self->{currentId} = $reader->getCurrentId();
	my $progress = $reader->getProgress();
	$progress = defined($progress)?sprintf("[%5.1f%%]",$progress*100):"";
	print "\rProcessing segment no ".$self->{currentNbSegmentsRead}." ".(($self->{currentNbSegmentsRead} eq $self->{currentId}?"":" (id ".$self->{currentId}.")"))." $progress ..." if ($self->{verbose});
	chomp($data);
	$self->{logger}->trace("Read '$data'");		
	my $tokens = $self->preprocessSegment($data, $probeOrRef);
	if (defined($tokens)) {
		$self->{logger}->debug("Processing segment no ".$self->{currentNbSegmentsRead}." (id ".$self->{currentId}."), tokens =  ( ".($self->{tokenizer}->returnsList()?join(" ",@$tokens):$tokens)." )") if ($self->{logger}->is_debug()); # test to avoid computing big expression whenever avoidable
	} else {
		$self->{logger}->debug("Segment no ".$self->{currentNbSegmentsRead}." (id ".$self->{currentId}.") ignored");
	}
	return $tokens;		
}


# TODO $probeOrRef now useless below and above

=head2 preprocessSegment($data, $probeOrRef)

returns the tokens corresponding to the given string according to the preprocessing options provided,
(as a list of tokens or a string) unless their number is lower than $self->{minTokens} (in this case returns undef) 

$probeOrRef = "probe" or "ref", in order to use the right ngrams parameter for frontiers

=cut

sub preprocessSegment {
	my ($self, $data, $probeOrRef)  = @_;
	my $tokens = $self->{tokenizer}->tokenize($data);
	my $nbTokens = $self->{tokenizer}->returnsList()?scalar(@$tokens):length($tokens);
	if ($nbTokens < $self->{minTokens}) {
		return undef;
	} else {
		if ($self->{addTokensFrontiers}) {
			$self->{logger}->debug("Adding 'frontiers' before and after the sequence of tokens");
			if ($self->{tokenizer}->returnsList()) {
				my @frontier = ($defaultFrontierChar) x $self->{sizeFrontiersTokens};
#				print "DEBUG: frontiers=".join(" | ", @frontier)."\n";
				my @tokens = (@frontier, @$tokens, @frontier);
#				print "DEBUG: tokens=".join(" | ", @tokens)."\n";
				$tokens = \@tokens;
			} else {
				my $frontier = $defaultFrontierChar x ($self->{sizeFrontiersTokens});
				$tokens = $frontier.$tokens.$frontier;
			}
		}
		return $tokens;
	}
}


=head2 printDebugFirstData($data)

writes detailed information (ngrams etc) to the log (if the level is at least debug)

=cut

sub printDebugFirstData {
	my $self = shift;
	my $refData = $self->{firstDataNGrams};
	my $indexData = undef;
	my $isIndexed;
	if ($self->{singleRefData}) {# only if first data = ref, error in new otherwise
		$self->{logger}->debug($self->{firstDataStr}." NGrams object: ".$refData->valuesAsShortStringWithDetails($self->{measure}->requiresSegmentsCountByNGram()?$self->{measure}->getIDFVector():undef)); xxx
		$indexData = $refData->indexAsShortString() if ($refData->isa("Text::TextAnalytics::IndexedNGrams"));
	} else {
		foreach my $id (keys %$refData) {
			# if $self->{measure}->requiresSegmentsCountByNGram() is true then first data = ref (error in new otherwise)
			$self->{logger}->debug($self->{firstDataStr}." NGrams object id '$id': ".$refData->{$id}->valuesAsShortStringWithDetails($self->{measure}->requiresSegmentsCountByNGram()?$self->{measure}->getIDFVector():undef));
			$indexData = $refData->{$id}->indexAsShortString() if ((!defined($indexData)) && ($refData->{$id}->isa("Text::TextAnalytics::IndexedNGrams"))); 
		}
	}
	if (defined ($indexData)) {
		$self->{logger}->debug("Shared index data: $indexData");
	}
	if ($self->{measure}->requiresSegmentsCountByNGram()) {
		my $idfs = $self->{measure}->getIDFVector();
		my $idfsString="";
		foreach my $key (sort {$idfs->{$a} <=> $idfs->{$b}} keys %$idfs) {
			$idfsString .= " $key: $idfs->{$key}";
		}
		$self->{logger}->debug("IDF values: $idfsString");
	}
}

=head2 usesSingleReferenceData()

see parent documentation

=cut

sub usesSingleReferenceData {
	my $self = shift;
	return $self->{singleRefData};	# if probe data first, error was raised in "new"
}



=head2 returnsScoresForSegmentPairs()

see parent documentation

=cut

sub returnsScoresForSegmentPairs {
	my $self = shift;
	return (!$self->{singleRefData});  # single ref = case where only one value as output
}

1;
