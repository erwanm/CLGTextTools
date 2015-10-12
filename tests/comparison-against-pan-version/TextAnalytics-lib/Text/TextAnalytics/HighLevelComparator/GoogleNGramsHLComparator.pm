package Text::TextAnalytics::HighLevelComparator::GoogleNGramsHLComparator;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::HighLevelComparator::StdHLComparator;
use  Text::TextAnalytics::Tokenizer::Tokenizer qw/$defaultFrontierChar/;
use Text::TextAnalytics qw/$prefixModuleMeasure $prefixModuleTokenizer $prefixModuleNGrams $prefixModuleSegmentReader $prefixModuleScoresConsumer
		genericObjectBuilder parseObjectDescription/;
use Text::TextAnalytics::ScoresConsumer::ScoresWriterConsumer;
use File::Basename;
use Scalar::Util 'blessed';


our @ISA = qw/Text::TextAnalytics::HighLevelComparator::StdHLComparator/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::HighLevelComparator::GoogleNGramsHLComparator -  



=cut





my %defaultOptions = (  
					   "addTokensFrontiers" => 0,
					   "minTokens" => 0,
					   "minNGrams" => 0,
					   "verbose" => 1, 
					   "information" => "",
					   "warnInvalidNGramsInGoogleFiles" => 0,
					   "onlyExistingNGramsInTotal" => 0,
					   "frequencyAs" => "match",
					   "documentFrequencyAs" => "book"
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
my @parametersVars = (
					   "addTokensFrontiers", 
					   "minTokens", 
   					   "minNGrams",
					   "verbose",
					   "warnInvalidNGramsInGoogleFiles",
					   "onlyExistingNGramsInTotal",
					   "frequencyAs",
					   "documentFrequencyAs"
					  );

my %columnNo = ( "match" => 1, "page" => 2, "book" => 3 );
my $multiLevelClassName = "Text::TextAnalytics::NGrams::MultiLevelNGrams";


=head1 DESCRIPTION

ISA = Text::TextAnalytics::HighLevelComparator::StdHLComparator

=head2 new($class, $params)

$params is an hash ref which optionally defines the following parameters: 

=over 2

=item *  addTokensFrontiers: boolean. adds "frontiers" at the beginning and end of every segment, e.g. if n=2 (ab, bc, cd) becomes (#a, ab, bc, cd, d#). 

=item *  minTokens: integer, minimum number of tokens for the segment to be taken into account

=item *  minNGrams: integer, minimum number of ngrams - after preprocessing - for the segment to be taken into account

=item * verbose: boolean. if 0, nothing is printed to stdout.

=item * information: string

=item * warnInvalidNGramsInGoogleFiles

=item * onlyExistingNGramsInTotal: count only the ngrams which appear in the probe file in the total (default: count all ngrams, possibly including errors) 

=item * frequencyAs: possible values = "match", "page", "book" ; column to use as the (absolute) frequency. default = match (number of occurrences).

=item * documentFrequencyAs: possible values = "match", "page", "book" ; column to use as the (absolute) document frequency, i.e. to consider
        as the number of segments containing this ngram (if used by the measure). default = book (number of books containing the ngram).

=back

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	return $self; 	
}


=head2 getParametersString($prefix)

see parent documentation

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
    my $str = $self->SUPER::getParametersString($prefix); # dirty, beurk
	$str .= $prefix."Google NGrams descriptor file: ".$self->{googleFilesDescrFile}."\n";
    $str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix,1);
	return $str;
}


=head2 compare($pathToGoogleFiles, $probeReader)


=cut

sub compare {
	my $self = shift;
	$self->{googleFilesDescrFile} = shift;
	my $probeReaderParam = shift;
	$self->{logger}->logconfess("Error: probe and/or reference reader parameters must be defined.") if (!defined($probeReaderParam));
	$self->{probeReader} = ref($probeReaderParam)?$probeReaderParam:genericObjectBuilder(parseObjectDescription($probeReaderParam), $Text::TextAnalytics::prefixModuleSegmentReader);

# TODO check that path is valid googleFilesDescrFile
	
	my $startDate = localtime();
	my $startTimeS = time();
	my $info = "Started $startDate (v. $VERSION)\n";
	print $info if ($self->{verbose});
	$self->{information} .= "# $info";
	$info = "Reading probe corpus to feed google reader with ngrams...";
	print "$info\n" if ($self->{verbose});
	$self->{logger}->info("$info");	
	# Caution: probe data loaded using the ref data parameters, because this first pass is only used to obtain the right ngrams from the google ngrams data
	($self->{dataNGrams}, $self->{nbSegments}) = $self->loadSegmentsAsNGrams( $self->{probeReader}, 1, undef, "ref" ); 
	$self->{information} .= $self->getParametersString("# ");
	if ($self->{dataNGrams}->ngramsAreUnique() && !$self->{dataNGrams}->isa($multiLevelClassName)) {
		$info = "In probe data: ".$self->{dataNGrams}->getNbDistinctNGrams()." distinct ngrams, accounting for a total of ".$self->{dataNGrams}->getTotalCount()." ngrams.";
		print "$info\n" if ($self->{verbose});
		$self->{logger}->info("$info");	
		$self->{information} .= "# $info\n";
	}
	print "\n" if ($self->{verbose});

	$info = "Reading google ngrams file(s) to find probe ngrams...";
	print "$info\n" if ($self->{verbose});
	$self->{logger}->info("$info");	
	my $segmentsCountByNGram = $self->{measure}->requiresSegmentsCountByNGram()?{}:undef;
	my $nbSegmentsProcessed;
	($self->{googleNGrams}, $nbSegmentsProcessed) = $self->obtainGoogleNGramsData($self->{dataNGrams}, $self->{googleFilesDescrFile}, $segmentsCountByNGram);
	$self->{measure}->setSegmentsCountByNGram($nbSegmentsProcessed, $segmentsCountByNGram, $self->{googleNGrams});
	print "\n" if ($self->{verbose});

	$self->{probeReader}->resetReader();
	$self->initializeConsumers($self->{information});
	$info = "Reading probe segments and comparing against google ngrams using ".$self->{measure}->getName()."...";
	print "$info\n"  if ($self->{verbose});
	$self->{logger}->info($info);
	$self->readSegmentsAndCompareNGrams($self->{probeReader}, $self->{googleNGrams});
	
	my $endDate = localtime();
	my $endTimeS = time();
	$self->{information} .= "# ended $endDate\n";
	$info  = sprintf("Time elapsed: %d seconds\n",($endTimeS-$startTimeS));
	print "$info"  if ($self->{verbose});
	$self->{information} .= "# $info";
	$self->finalizeConsumers($self->{information});
}


=head2

warning: prototype!

file descr expected format = every line start with N (length of n-grams) followed by a sequence of filenames (path interpreted from the location of the descr file), separated by tabulations

only 4 fields on each line in the google ngrams files: <ngram> <match count> <page count> <volume count>
no YEAR

currently match count is used as a frequency
 
=cut

sub obtainGoogleNGramsData {
	my $self = shift;
	my $ngramsToFind = shift;
	my $pathToGoogleNgramsDescrFile = shift;
	my $segmentsCountByNGram = shift;
	my %ngramsFiles;
	my $googleNGrams = genericObjectBuilder($self->{refNGramsClassName},{ shared => $ngramsToFind, %{$self->{refNGramsParams}} }, $prefixModuleNGrams);
	open(DESCRFILE, "<:encoding(utf-8)",$pathToGoogleNgramsDescrFile) or confess("can not open file $pathToGoogleNgramsDescrFile");
	my $freqColNo = $columnNo{$self->{frequencyAs}};
	my $docFreqColNo = $columnNo{$self->{documentFrequencyAs}};
	while (<DESCRFILE>) {
		chomp;
		my @t = split(/\t/);
		my $n = shift(@t);
		$ngramsFiles{$n} = \@t;
	}
	close(DESCRFILE);
	my @parsed = fileparse($pathToGoogleNgramsDescrFile);
	my $dirName = $parsed[1];
	my %extendedSizeValues;
	my %maxDocs;
	if ($googleNGrams->isa($multiLevelClassName)) { # TODO not really clean
		for (my $levelNo = 0; $levelNo < $googleNGrams->getNbLevels(); $levelNo++) {
			$maxDocs{$levelNo} = 0;
			my $size = $googleNGrams->getLevelExtendedSize($levelNo);
			 if (defined($ngramsFiles{$size})) {
				push(@{$extendedSizeValues{$size}}, $levelNo);
			 } else {
				$self->{logger}->logwarn("Warning: impossible to take level $levelNo into account: there is no google ngrams file for length $size");
			 }
		}
	} else {
		$maxDocs{-1} = 0;
		$extendedSizeValues{$googleNGrams->getN()} = [ -1 ];
	}
	my $startTimeS = time();
	foreach my $extendedSize (sort keys %extendedSizeValues) {
		my $nbSeen = 0;
		my $nbInvalidNGrams = 0;
		my %total;
		my %nbAdded;
		print "Parsing google ngrams file(s) for ngrams of length $extendedSize\n" if ($self->{verbose});
		foreach my $filename (@{$ngramsFiles{$extendedSize}}) {
			open(FILE, "<:encoding(utf-8)", "$dirName/$filename") or confess("can not open file $dirName/$filename");
			my $lineNo=1;
			my $lastTime = $startTimeS;
			while (<FILE>) {
				my $currentTime = time();
				chomp;
				my @values = split(/\t/);			
				my $ngram = $values[0];
				my @ngram = split(" ", $ngram);
				if (scalar(@values) != 4) {
					$nbInvalidNGrams++;
					$self->{logger}->logwarn("Warning: wrong number of columns in $filename line $lineNo, ignored") if ($self->{warnInvalidNGramsInGoogleFiles});
				}
				if (scalar(@ngram) != $extendedSize) {
					$nbInvalidNGrams++;
					$self->{logger}->logwarn("Warning: invalid $extendedSize-gram in file $filename line $lineNo '$ngram', ignored") if ($self->{warnInvalidNGramsInGoogleFiles});
				} else {
					my $freq = $values[$freqColNo];
					my $docFreq = $values[$docFreqColNo];
					$nbSeen++;
					foreach my $level (@{$extendedSizeValues{$extendedSize}}) {
						$maxDocs{$level} = $docFreq if ($docFreq > $maxDocs{$level});
						print "\r$nbSeen ngrams seen, ($nbAdded{$level} added)..." if ($self->{verbose} && defined($nbAdded{$level}) && ($currentTime > $lastTime));
						$total{$level} += $freq if (!$self->{onlyExistingNGramsInTotal});
						my ($key, $value); 
						if ($level==-1) {
							$key = $ngramsToFind->getKey(\@ngram);
							if (defined($key)) {
							    $value = $ngramsToFind->getValueFromKey($key);
							    if (defined($value)) { # if the ngram exists in $ngramsToFind (warning: the index must not have been shared before!)
								$self->{logger}->logwarn("Error: ngram '".join(" ", @ngram)."' appears (at least) twice in google ngrams!") if (defined($googleNGrams->getValueFromKey($key)));
								$googleNGrams->setValueFromKey($key, $freq);
								$segmentsCountByNGram->{$key} = $docFreq if (defined($segmentsCountByNGram));
								$total{$level} += $freq if ($self->{onlyExistingNGramsInTotal});
								$nbAdded{$level}++;
							    }
							}
						} else {
							my $possibleSkipGram = \@ngram;
							$possibleSkipGram = $ngramsToFind->extractNGramFromPattern($level, \@ngram, 0) if (defined($ngramsToFind->getPattern($level)));
							$key = $ngramsToFind->getKeyLevel($possibleSkipGram, $level);
							if (defined($key)) {
							    $value = $ngramsToFind->getValueFromKeyLevel($key, $level);
							    if (defined($value)) { # if the ngram exists in $ngramsToFind (warning: the index must not have been shared before!)
								$self->{logger}->logwarn("Error: ngram '".join(" ", @$possibleSkipGram)."' appears (at least) twice in google ngrams!") if (defined($googleNGrams->getValueFromKeyLevel($key, $level)));
								$googleNGrams->setValueFromKeyLevel($key, $freq, $level);
								$segmentsCountByNGram->[$level]->{$key} = $docFreq if (defined($segmentsCountByNGram));
								$total{$level} += $freq if ($self->{onlyExistingNGramsInTotal});
								$nbAdded{$level}++;
							    }
							}
						}
					}
					$lastTime = $currentTime;
				}
				$lineNo++;
			}
			close(FILE);
		}
		print "\n" if ($self->{verbose});
		foreach my $level (keys %total) {
			if ($level == -1) {
				$googleNGrams->setTotalCount($total{$level});
			} else {
				$googleNGrams->setTotalCountLevel($total{$level}, $level);
			}
			if ($self->{verbose}) {
				my $nbDistinctGoogle = ($level == -1)?$googleNGrams->getNbDistinctNGrams():$googleNGrams->getNbDistinctNGramsLevel($level);
				my $nbDistinctProbe = ($level == -1)?$ngramsToFind->getNbDistinctNGrams():$ngramsToFind->getNbDistinctNGramsLevel($level);
				my $info ="";
				$info .= "Level $level: " if ($level != -1);
				$info .= "$nbAdded{$level} ngrams have been added among $nbSeen ($nbInvalidNGrams invalid ngrams discarded). Coverage (google ref / probe) = $nbDistinctGoogle / $nbDistinctProbe = ".sprintf("%3.2f %%", $nbDistinctGoogle / $nbDistinctProbe * 100)."\n";
				print "\n$info\n" if ($self->{verbose});
				$self->{logger}->info("$info");
			}	
		}
	}
	my $endTimeS = time();
	my $info  = sprintf("Time spent to load Google ngrams: %d seconds\n",($endTimeS-$startTimeS));
	print "$info\n" if ($self->{verbose});
	$self->{logger}->info("$info");	
	
	my @nbDocs = map { $maxDocs{$_} } (sort { $a <=> $b } keys %maxDocs);
	return ($googleNGrams->isa($multiLevelClassName))?($googleNGrams, \@nbDocs):($googleNGrams, $maxDocs{-1});
}



=head2 usesSingleReferenceData()

see parent documentation

=cut

sub usesSingleReferenceData {
	return 1;	
}



=head2 returnsScoresForSegmentPairs()

see parent documentation

=cut

sub returnsScoresForSegmentPairs {
	return 0;
}

1;
