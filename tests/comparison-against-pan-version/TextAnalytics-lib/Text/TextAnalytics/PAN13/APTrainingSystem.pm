package Text::TextAnalytics::PAN13::APTrainingSystem;


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Text::TextAnalytics::Util qw/readFileAsTokensList readTSVWithHeaderAsColumnsHash pickNAmongSloppy pickNIndexesAmongMSloppy readTSVByColumnsNoHeader readConfigFile mean max/;
use Text::TextAnalytics::PAN13::Config;
use Data::Dumper;

our $VERSION = $Text::TextAnalytics::VERSION;

my $defaultLogLevel = "INFO";
my $answersFilename = "answers.xml";
my $dataTSVFile = "data.tsv";

my $defaultLearningParams = {
		maxIter => 99999,
#		nbConfigsIter => 30,
		nbConfigsIter => 50,
#		nbConfigsIter => 50,
#		testSetSize => 2000,
#		testSetSize => 150,
#		testSetSize => 150,
		testSetSize => 200,
#		selectConfigAmongMult => 100,
		nbFoldsWeka => 5,
#		metaFeaturesSelection => "max",
		metaFeaturesSelection => "mean", # or max
		testDataFeaturesDir => "test-features.aligned",
		stopProcessesRatio => 0.9,
		timeOutWeka => 300,
#		timeOutWeka => 60
		saveMem => undef,
		sleepTimeLearnerProcess => 60
};


sub new {
	my ($class, $params) = @_;
	my $self = $params;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	$self->{logger} = $logger;
	$logger->info("Creating ".__PACKAGE__." object.");
	$logger->logconfess("workDir is undef") if (!defined($params->{workDir}));
	$logger->logconfess("dataDir is undef") if (!defined($params->{dataDir}));
	for my $p (keys %$defaultLearningParams) {
		$self->{learningParams}->{$p} = $defaultLearningParams->{$p} unless (defined($params->{learningParams}->{$p}));
	    $logger->debug("Parameter $p=".$self->{learningParams}->{$p}) if (defined($self->{learningParams}->{$p}));
	} 
	$self->{nbDigitsIter} = length($self->{learningParams}->{maxIter});
	$logger->info("self->{learningParams}:");
	$logger->info({ filter => \&Dumper, value => $self->{learningParams} });
	$self->{languages} = readFileAsTokensList($self->{dataDir}."/languages.list", $logger);
	$logger->info("Init languages: ".join(",", @{$self->{languages}}));
	# assuming same features types and categories for all languages
	my $lang = $self->{languages}->[0];
	$self->{categories} = readFileAsTokensList($self->{dataDir}."/$lang/categories.list", $logger);
# TODO TEMP
#	$self->{categories} = [ "10s", "male", "20s_female", "30s_female" ] ;
	$logger->info("Init categories: ".join(",", @{$self->{categories}}));
	$self->{featuresTypes} = readFileAsTokensList($self->{dataDir}."/$lang/features-types.list", $logger);
# TODO TEMP
#	$self->{featuresTypes} = [ "c1", "P" ];
	$logger->info("Loaded features types: ".join(",", @{$self->{featuresTypes}}));
	my $workDir = $self->{workDir};
	foreach my $lang (@{$self->{languages}}) {
		if (!defined($self->{learningParams}->{saveMem})) {
			$logger->info("Loading ref data (stats) for language $lang");
			$self->{stats}->{$lang} = loadAllStats($self->{dataDir}."/$lang", $self->{categories}, $self->{featuresTypes}, $logger);
		}
		$logger->info("Reading test data files for language $lang");
		$self->{testSet}->{$lang} = readTestList($self->{dataDir}."/$lang/data.tsv", $logger);
		$logger->info("Creating directories for language $lang");
		mkdir "$workDir/indexes" unless (-d "$workDir/indexes");
		mkdir "$workDir/indexes/$lang" unless (-d "$workDir/indexes/$lang");
		mkdir "$workDir/iterations" unless (-d "$workDir/iterations");
		foreach my $categ (@{$self->{categories}}) {
			mkdir "$workDir/indexes/$lang/$categ" unless (-d "$workDir/indexes/$lang/$categ");
			foreach my $ft (@{$self->{featuresTypes}}) {
				mkdir "$workDir/indexes/$lang/$categ/$ft" unless (-d "$workDir/indexes/$lang/$categ/$ft");
			} 
		} 
	}
	bless($self, $class);
	return $self;
}


sub loadAllStats {
	my ($dir, $categs, $feats, $logger) = @_;
	my %data;
	foreach my $categ (@$categs) {
		foreach my $featType (@$feats) {
		    my $absRel = "rel";
#			foreach my $absRel ("abs", "rel") {
				$logger->trace("Loading table for categ=$categ, featTye=$featType, absRel=$absRel");
				my $content = readTSVWithHeaderAsColumnsHash("$dir/$categ.$featType.$absRel.stats", $logger);
				$data{$categ}->{$featType}->{$absRel} = $content;
				if ($logger->is_debug()) {
					my ($colId, $colContent) = each (%$content);
					$logger->trace(scalar(keys %$content)." columns * ".scalar(@$colContent)." rows loaded") ;
#				}
			}
		}
	}
	return \%data;
}


sub readTestList {
	my ($file, $logger) = @_;
	my @instances;
	open(FILE, "<", $file) or $logger->logconfess("Can not open test set file $file");
	my $lineNo=1;
	while (<FILE>) {
		chomp;
		my %instance;
		my @cols = split;
		($instance{id}, $instance{age}, $instance{gender}, $instance{ageGenderPair}) = @cols;
		$logger->trace("Loading test file id=$instance{id}, age=$instance{age}, gender=$instance{gender}, ageGenderPair=$instance{ageGenderPair}");
		$logger->logconfess("Error invalid format in test set file $file line $lineNo: ".join(" ",@cols)) unless (defined($instance{ageGenderPair}));
		$lineNo++;
		push(@instances, \%instance);
	}
	close(FILE);
	return \@instances;
}

sub parseApplyGenerateParam {
    my $self = shift;
    my $p = shift;
    my $checkModel = shift;
    if ($checkModel) { # APPLY dirty
	my $newP;
	($newP, $self->{destDir}) = ($p =~ m/^([^;]+);([^;]+)$/);
	$self->{logger}->logconfess("ivalid format parameter $p") if (!$self->{destDir});
	$p = $newP;
    }
    my ($confDir, $modelDir) = ($p =~ m/^([^:]+):([^:]+)$/);
    $self->{logger}->logconfess("ivalid format parameter $p") if (!$modelDir);
    my %res;
    foreach my $lang (@{$self->{languages}}) {
	if ((!$checkModel) || (-f "$modelDir/$lang.model")) {
	    $res{$lang}->{model} = "$modelDir/$lang.model";
	    mkdir "$modelDir" if (! -d "$modelDir");
	} else {
	    $self->{logger}->logconfess("Error: model file $modelDir/$lang.model does not exist");
	}
	# config always checked
	if (-f "$confDir/$lang.conf") {
	    $res{$lang}->{config} = "$confDir/$lang.conf";
	} else {
	    $self->{logger}->logconfess("Error: config file $confDir/$lang.conf does not exist");
	}
    }
    return \%res;
    
}

sub run {
	my $self = shift;
	my $params = shift;
	if (defined($params->{applyModel})) {
	    $self->runApplyGen($self->parseApplyGenerateParam($params->{applyModel}, 1), 1);
	} elsif (defined($params->{generateModel})) {
	    $self->runApplyGen($self->parseApplyGenerateParam($params->{generateModel}, 0), 0);
	} else {
	    my $iterStart = (defined($params->{resumeAt})) ? $params->{resumeAt} : 0;
	    $self->{logger}->info("Starting iteration process from iteration $iterStart");
	    for (my $iterNo=$iterStart; $iterNo < $self->{learningParams}->{maxIter}; $iterNo++) {
		$self->{currentIterId} = sprintf("%0".$self->{nbDigitsIter}."d", $iterNo);
		$self->runIteration($params->{nbParallel}?$params->{nbParallel}:1);
	    }
	}
		
}

sub runApplyGen {
    my $self = shift;
    my $params = shift;
    my $isApply = shift;
    # using the full test  set, but one by one because only one config
    my %answers;
    foreach my $lang (@{$self->{languages}}) {
	my @l = (0..scalar(@{$self->{testSet}->{$lang}})-1);
	my $indexes = \@l;
#	$self->{logger}->info({filter=> \&Dumper, value=> $indexes});
	$self->{logger}->info("Loading config for $lang from  ".$params->{$lang}->{config});
	my $config = Text::TextAnalytics::PAN13::Config->newFromFile($params->{$lang}->{config});
	$self->{logger}->info("nb instances in test set for $lang : ".scalar(@$indexes));
	$self->{logger}->info("Computing distances (features) for $lang");
	my $distancesByCatFTTestSetId = $config->computeDistances($self, $lang, $indexes, 1);
	my $genParam = $isApply ? undef : $params->{$lang}->{model} ;
	my $applyParam = $isApply ? $params->{$lang}->{model} : undef ;
	$self->{logger}->info("Starting ".($isApply?"testing":"training")." process for $lang : ".scalar(@$indexes));
	$config->createArffAndRunWeka($self, $lang, $distancesByCatFTTestSetId, $indexes, $self->{workDir}."/$lang", $genParam, $applyParam);
	if ($isApply) { # if generate, we're done, but if apply, collect the answers
	    $self->{logger}->info("Collecting answers for $lang");
	    $self->{logger}->logconfess("Error output ".$self->{workDir}."/$lang.output.arff"." file not found ") if (! -f $self->{workDir}."/$lang.output.arff");
	    my $accu;
	    ($answers{$lang}, $accu) = $self->collectAnswers($self->{workDir}."/$lang.output.arff", $indexes, $lang);
	    print "Accuracy for $lang: $accu\n";
	}
    }

    if ($isApply) { # if generate, we're done, but if apply, collect the answers
	$self->{logger}->info("Writing answers to xml file '".$self->{workDir}."/$answersFilename'");
	$self->writeXMLAnswers($self->{destDir}, \%answers);
    }
}


sub writeXMLAnswers {
    my $self = shift;
    my $destDir = shift;
    my $answers = shift;
    
    (-d $destDir) || mkdir $destDir;
    foreach my $lang (keys %$answers) {
	foreach my $id (keys %{$answers->{$lang}}) {
	    my $age = $answers->{$lang}->{$id}->{age};
	    my $gender = $answers->{$lang}->{$id}->{gender};
	    my $filename = "$destDir/$id.xml";
	    open(OUT, ">", $filename) or $self->{logger}->logconfess("can not open $filename for writing");
	    print OUT "<author\n";
	    print OUT "id=\"$id\"\n";
	    print OUT "lang=\"$lang\"\n";
	    print OUT "age_group=\"$age\"\n";
	    print OUT "gender=\"$gender\"\n";
	    print OUT "/>\n";
	    close(OUT);
	}
    }
}

sub collectAnswers {
    my $self = shift;
    my $inputFile = shift;
    my $indexes = shift;
    my $lang = shift;

    my %res;
    open(INPUT, "<", $inputFile) or $self->{logger}->logconfess("cannot open $inputFile");
    my $data=0;
    my $nbCols;
    my $tp=0;
    my $indexTestId=0;
    while (<INPUT>) {
	chomp;
	if (m/\S+/) {
	    if ($data) {
		my @cols = split(",", $_);
		if (defined($nbCols)) {
		    $self->{logger}->logconfess("BUG wrong number of cols in arff file $inputFile") unless ($nbCols==scalar(@cols));
		} else {
		    $nbCols=scalar(@cols);
		}
		my $class  = $cols[scalar(@cols)-1];
		my ($age, $gender) = ($class =~ m/^C(.+)_(.+)$/);
		my $instanceDescr = $self->{testSet}->{$lang}->[$indexes->[$indexTestId]];
		my ($id) = ($instanceDescr->{id} =~ m/^([^_]+)_/);
		$self->{logger}->logconfess("BUG can not parse class '$class'") if (!defined($gender));
		$self->{logger}->debug("Answer for id=$id: age=$age gender=$gender ; instanceDescr=$instanceDescr");
		$res{$id} ={ age=>$age, gender=>$gender };
		if (($instanceDescr->{age} eq $age) && ($instanceDescr->{gender} eq $gender)) {
		    $tp++;
		}
		$indexTestId++;
	    } elsif (m/\@data/i) {
		$data=1;
	    } # otherwise header
	}
    }
    $self->{logger}->logconfess("BUG $indexTestId instances collected but test set contains ".scalar(@{$self->{testSet}->{$lang}})." instances " ) if ($indexTestId != scalar(@{$self->{testSet}->{$lang}}));
    close(INPUT);
    return (\%res, $tp / scalar(@$indexes));
}


sub runIteration {
	my $self = shift;
	my $nbParallel = shift;
	my $iterId = $self->{currentIterId} ;

	# BEFORE
	$self->{logger}->info("Starting iteration ".$self->{currentIterId});
	mkdir $self->{workDir}."/iterations/".$iterId unless (-d $self->{workDir}."/iterations/".$iterId);
	my %configsAndMF;
	my $metaFeaturesScores; 
	foreach my $lang (@{$self->{languages}}) {
		$self->{logger}->info("Preparing iteration for language $lang");
		mkdir $self->{workDir}."/iterations/".$iterId."/".$lang unless (-d $self->{workDir}."/iterations/".$iterId."/".$lang);
		mkdir $self->{workDir}."/iterations/$iterId/$lang/configs" unless (-d $self->{workDir}."/iterations/$iterId/$lang/configs");
		mkdir $self->{workDir}."/iterations/$iterId/$lang/distances" unless (-d $self->{workDir}."/iterations/$iterId/$lang/distances");
		foreach my $categ (@{$self->{categories}}) {
			mkdir $self->{workDir}."/iterations/$iterId/$lang/distances/$categ" unless (-d $self->{workDir}."/iterations/$iterId/$lang/distances/$categ");
		}
		my $configsDir = $self->{workDir}."/iterations/$iterId/$lang/configs";
		# 1. pick configs
		if ($iterId == 0) {
		    $self->{logger}->debug("First iteration: picking ".$self->{learningParams}->{nbConfigsIter}." configs randomly");
		    $metaFeaturesScores->{$lang} = {};
		} else {
			$self->{logger}->debug("Loading meta-features scores from iteration".($iterId-1));
			$self->{logger}->debug("Loading meta-features scores from iteration".($iterId-1));
			$metaFeaturesScores->{$lang} = $self->loadMetaFeaturesScores($lang, $iterId-1); 
		}
		my @configs;
		for (my $i=0; $i<$self->{learningParams}->{nbConfigsIter}; $i++) {
		    push(@configs, Text::TextAnalytics::PAN13::Config->newRandom($self->{categories}, $self->{featuresTypes}, $metaFeaturesScores->{$lang}, $self->{learningParams}->{metaFeaturesSelection} ));
		}
		$self->{logger}->debug("Computing meta-features");
		for (my $i=0; $i<scalar(@configs); $i++) {
			$configsAndMF{$lang}->[$i] = { "config" => $configs[$i],  "metaFeatures" => $configs[$i]->getMetaFeatures() }; 
		}
		$self->{logger}->debug("Writing configs for $lang");
		Text::TextAnalytics::PAN13::Config::writeConfigs($configsAndMF{$lang},$configsDir, $self->{logger});
		# 2. test set
		$self->{logger}->debug("Picking ".$self->{learningParams}->{testSetSize}." test files as test set");
		my $indexes = pickNIndexesAmongMSloppy($self->{learningParams}->{testSetSize}, scalar(@{$self->{testSet}->{$lang}}));
		$self->{logger}->debug("nb instances in test set for $lang : ".scalar(@$indexes));
		if (!defined($self->{learningParams}->{saveMem})) {
			$self->{logger}->debug("loading data from test set files");
			$self->{currentTestSet}->{$lang} = {};
			foreach my $i (@$indexes) {
			    $self->{currentTestSet}->{$lang}->{$i} = $self->loadTestFileContent($i, $lang, $self->{featuresTypes});
			}
		} else {
			$self->{logger}->debug("saveMem mode: only storing indexes");
			$self->{currentTestSetIds}->{$lang} = $indexes;
		}
	}
	
	# DURING
	$self->{logger}->info("Main: computing results for every config in every language");
	my $results = (!defined($self->{learningParams}->{saveMem})) ? $self->computeConfigs(\%configsAndMF, $nbParallel) : $self->computeConfigsSaveMem(\%configsAndMF, $nbParallel);
			
	
	# AFTER
	foreach my $lang (@{$self->{languages}}) {
		$self->{logger}->info("Updating meta-features based on new results for language $lang");
		my $newMetaFeaturesScores  = Text::TextAnalytics::PAN13::Config::scoreMetaFeatures($configsAndMF{$lang}, $results->{$lang}, $metaFeaturesScores->{$lang}, $self->{logger});
		$self->{logger}->debug("Writing updated meta-features");
		$self->writeMetaFeaturesScores($lang, $newMetaFeaturesScores, $iterId);
		my @values = values %{$results->{$lang}};
		$self->{logger}->info("Results for iteration ".$self->{currentIterId}.", language $lang: avg = ".mean(\@values, "NA")." ; max = ".max(\@values, "NA"));
	}

}

sub computeConfigs {
	my $self = shift;
	my $configsAndMF = shift;
	my $nbParallel = shift;
	
	my $iterId = $self->{currentIterId} ;
	my $workDir = $self->{workDir}."/iterations/$iterId";
	my $stopFile = "$workDir/last-processes.stop";
	
	unlink($stopFile) if (-f $stopFile);
	if ($nbParallel == 1) {
		$self->{logger}->info("Computing results using a single process");
		$self->computeConfigsSingleProcess($configsAndMF, 0, $self->{learningParams}->{nbConfigsIter}, $workDir, 0, $stopFile);
	} else {
	    my $nbByProcess = $self->{learningParams}->{nbConfigsIter} / $nbParallel;
	    $nbByProcess = int($nbByProcess)+1 if (int($nbByProcess)<$nbByProcess);
	    $self->{logger}->info("Computing results using $nbParallel processes, $nbByProcess configs by process");
	    my @pids;
	    for (my $processNo=0; $processNo<$nbParallel; $processNo++) {
			my $startAtConfig =  $processNo * $nbByProcess;
			$pids[$processNo] = fork();
			$self->{logger}->logconfess("Cannot fork: $!") if (!defined($pids[$processNo]));
			if (!$pids[$processNo]) {  # only the subprocess here.
		    	$self->{logger}->info("Process $processNo: starting from config $startAtConfig");
		    	$self->computeConfigsSingleProcess($configsAndMF, $startAtConfig, $startAtConfig+$nbByProcess, $workDir, $processNo, $stopFile);
		    	exit 0;
			}
	    }
	    
	    # wait processes
	    $self->waitProcesses($nbParallel, \@pids, $stopFile);
	}

	# collect results
	return $self->collectResults($nbParallel, $workDir);
}


sub computeConfigsSaveMem {
	my $self = shift;
	my $configsAndMF = shift;
	my $nbParallel = shift;
	
	my $iterId = $self->{currentIterId} ;
	my $workDir = $self->{workDir}."/iterations/$iterId";
	my $nbDigitsConfig = length($self->{learningParams}->{nbConfigsIter});
	

	

	die "TEMP BUG";

	my $nbCategs = scalar(@{$self->{categories}});
	my $firstConfigProcessor = $nbParallel - $nbCategs; # $firstConfigProcessor = nb learner processes
	if (($nbParallel>1) && ($nbParallel<$nbCategs)) {
		$self->{logger}->logconfess("Impossible to apply the saveMem method with $nbParallel processes when there are $nbCategs categories: need either only 1 or at least $nbCategs");
	}	

	if ($nbParallel == 1) { 
		# TODO
		$self->{logger}->info("Computing results using a single process");
#		$self->computeConfigsSingleProcess($configsAndMF, 0, $self->{learningParams}->{nbConfigsIter}, $workDir, 0);
	} else {
		if ($firstConfigProcessor>0) {
		    $self->{logger}->info("Computing results using $nbParallel processes: 0 to ".($firstConfigProcessor-1)." are learners,  $firstConfigProcessor to ".($nbParallel-1)." process configs for a given category.");
		} else {
		    $self->{logger}->info("Computing results using $nbParallel processes: $firstConfigProcessor to ".($nbParallel-1)." process configs for a given category, learning wil place after all finished.");
		}
	    my @pids;
	    
	    for (my $processNo=0; $processNo<$nbParallel; $processNo++) {
			$pids[$processNo] = fork();
			$self->{logger}->logconfess("Cannot fork: $!") if (!defined($pids[$processNo]));
			if (!$pids[$processNo]) {  # only the subprocess here.
				if ($processNo<$firstConfigProcessor) {
					$self->learnerProcess($processNo, $firstConfigProcessor, $configsAndMF);
				} else {
					$self->categDistWriterProcess($processNo, $self->{categories}->[$processNo-$firstConfigProcessor], $configsAndMF); ###########################################
				}
		    	exit 0;
			}
	    }
	    # wait processes
	    $self->waitProcesses($nbParallel, \@pids);
	}
	if (($nbParallel == 1) || ($firstConfigProcessor == 0)) { # learning has not been done yet
			$self->learnerProcess(0, 1, $configsAndMF);
	}
	# collect results
	return $self->collectResults($nbParallel - $nbCategs, $workDir);
}



sub categDistWriterProcess {
	my $self = shift;
	my $processNo= shift;
	my $categ = shift;
	my $configsAndMF = shift;

	my $iterId = $self->{currentIterId} ;
	my $workDir = $self->{workDir}."/iterations/$iterId";
	my $nbDigitsConfig = length($self->{learningParams}->{nbConfigsIter});
	
	$self->{logger}->info("Process $processNo: my task is computing distances for category $categ");
	foreach my $lang (@{$self->{languages}}) {
	    $self->{logger}->debug("Process $processNo: loading ref data for category $categ, lang $lang");
	    $self->{stats}->{$lang} = loadAllStats($self->{dataDir}."/$lang", [ $categ ], $self->{featuresTypes}, $self->{logger});
	}
	for (my $configNo=0; $configNo<$self->{learningParams}->{nbConfigsIter} ; $configNo++) {
		my $configNoStr = sprintf("%0".$nbDigitsConfig."d", $configNo);
		foreach my $lang (@{$self->{languages}}) {
			$self->{logger}->debug("Process $processNo: computing config $configNoStr for $lang; my categ is $categ");
			my $myPrefix = $self->{workDir}."/iterations/$iterId/$lang/distances/$categ/$configNoStr";
			$configsAndMF->{$lang}->[$configNo]->{config}->computeDistancesForSingleCategAndWriteToFile($self, $lang, $categ, $myPrefix, $self->{currentTestSetIds}->{$lang});
		}
	}			    	
}



sub learnerProcess {
	my $self = shift;
	my $processNo= shift;
	my $firstConfigProcessor = shift;
	my $configsAndMF = shift;
	
	my $iterId = $self->{currentIterId} ;
	my $workDir = $self->{workDir}."/iterations/$iterId";
	my $nbDigitsConfig = length($self->{learningParams}->{nbConfigsIter});
	my $sleepTime = $self->{learningParams}->{sleepTimeLearnerProcess};
   	$self->{logger}->info("Process $processNo: my task is weka learning");
   	
	my %byLang;
  	foreach my $lang (@{$self->{languages}}) {
		my $f = "$workDir/$lang/results.$processNo.tsv";
		my $fh;
		open($fh, ">", $f) or $self->{logger}->logconfess("can not write to $f: $!");
		$byLang{$lang}->{resultsFile} = $fh;
		$byLang{$lang}->{nextConfig} = $processNo;
	}
	my $nbLangAllDone = 0;
#   	for (my $configNo = $processNo; $configNo < $self->{learningParams}->{nbConfigsIter}; $configNo += $firstConfigProcessor) { # iterates by "windows", where window size = nb learners
	while ($nbLangAllDone < scalar(@{$self->{languages}})) {
		$nbLangAllDone = 0;
		my $doneSomething=0;
		foreach my $lang (@{$self->{languages}}) {
			if ($byLang{$lang}->{nextConfig} < $self->{learningParams}->{nbConfigsIter}) {
				my $configNoStr = sprintf("%0".$nbDigitsConfig."d", $byLang{$lang}->{nextConfig});
				my $distDir = $self->{workDir}."/iterations/$iterId/$lang/distances"; #"/$categ/$configNoStr";
				my %categsDone;
				foreach my $categ (@{$self->{categories}}) {
					$categsDone{$categ} = 1 if (-f $distDir."/$categ/$configNoStr.done");
				}
				if (scalar(keys %categsDone) == scalar(@{$self->{categories}})) {
					# compute weka
					my $res = $configsAndMF->{$lang}->[$configNoStr]->{config}->computePerf($self, $lang, "$workDir/$lang/$iterId.$configNoStr", $distDir, $configNoStr);
					$self->{logger}->trace("Process $processNo (learner), $lang: writing result=$res for config $configNoStr");
					my $fh = $byLang{$lang}->{resultsFile};
					print $fh "$configNoStr\t$res\n";
					$byLang{$lang}->{nextConfig} += $firstConfigProcessor;
					$doneSomething = 1;
				}
			} else {
				$self->{logger}->debug("Process $processNo (learner), $lang: everything done");
				$nbLangAllDone++;
			}
		}
		$self->{logger}->trace("Process $processNo: (learner): waiting (sleeping $sleepTime)");
		sleep $sleepTime if (!$doneSomething);
   	}
   	foreach my $lang (@{$self->{languages}}) {
		my $fh = $byLang{$lang}->{resultsFile};
		close($fh);
   	}   	
	
}



sub waitProcesses {
	my $self = shift;
	my $nbParallel = shift;
	my $pids = shift;
	my $stopFilename = shift; # if not defined, do not apply this interrupting system
		my $nbDone=0;
	    while ($nbDone < $nbParallel) {
			my $pid = wait();
			$self->{logger}->debug("Wait finished with pid $pid");
			my $exitStatus = $? >> 8;
			$nbDone++;
			for (my $i=0;$i<$nbParallel;$i++) {
			    if ($pid == $pids->[$i]) {
					if ($exitStatus != 0) {
					    $self->{logger}->logwarn("Something went wrong with process $i (pid $pid). exit status: $exitStatus");
					} else {
					    $self->{logger}->info("Process $i (pid $pid) has finished. $nbDone processes have finished until now");
					}
					if ($stopFilename && ($nbDone / $nbParallel > $self->{learningParams}->{stopProcessesRatio})) { 
					    $self->{logger}->info("$nbDone / $nbParallel processes have finished, asking others to stop.");
					    open(FILE, ">", $stopFilename) or $self->{logger}->logconfess("can not create $stopFilename");
					    print FILE "STOP IT NOW\n";
					    close(FILE);
					}
					last;
			    }
			}
	    }
}

sub collectResults {

	my $self = shift;
	my $nbParallel = shift;
	my $workDir = shift;
	
	my %res;
	foreach my $lang (@{$self->{languages}}) {
		$self->{logger}->info("Collecting results for language $lang");
		for (my $processNo=0; $processNo<$nbParallel; $processNo++) {
			my $f = "$workDir/$lang/results.$processNo.tsv";
			$self->{logger}->debug("Results from process $processNo read from $f ($lang)");
			open(FILE, "<", $f) or $self->{logger}->logconfess("can not read $f: $!");
			my $nb=0;
			my $nas = 0;
			while (<FILE>) {
				chomp;
				my @cols = split;
				my $res;
				if ((scalar(@cols)==2) && ($cols[1] !~ m/^\s*$/)) {
					$res = $cols[1];
				} else {
					$res = "NA";
					$nas++;
				}
				$res{$lang}->{$cols[0]} = $res;
				$nb++;
			}
			close(FILE);
			$self->{logger}->info("Results from process $processNo, $lang: $nb configs found, among which $nas NA values");
		}
	}	
	return \%res;
}

sub computeConfigsSingleProcess {
	my $self = shift;
	my $configsAndMF = shift;
	my $startAtConfig = shift;
	my $stopAtConfig = shift;
	my $workDir = shift;
	my $processNo= shift;
	my $stopFile = shift;

	my $nbDigitsConfig = length($self->{learningParams}->{nbConfigsIter});
	my $iterId = $self->{currentIterId} ;
	my %resultsFileHandles;
	
	foreach my $lang (@{$self->{languages}}) {
		 my $f = "$workDir/$lang/results.$processNo.tsv";
		 my $fh;
		 open($fh, ">", $f) or $self->{logger}->logconfess("can not write to $f: $!");
		$resultsFileHandles{$lang} = $fh;
	}
	for (my $configNo=$startAtConfig; $configNo<$self->{learningParams}->{nbConfigsIter} && $configNo<$stopAtConfig; $configNo++) {
		my $configNoStr = sprintf("%0".$nbDigitsConfig."d", $configNo);
		foreach my $lang (@{$self->{languages}}) {
			$self->{logger}->info("Process $processNo: computing config $configNoStr for $lang");
			my $res = $configsAndMF->{$lang}->[$configNo]->{config}->computePerf($self, $lang, "$workDir/$lang/$iterId.$configNoStr", undef);
			$self->{logger}->trace("Process $processNo, $lang: writing result=$res for config $configNoStr");
			my $fh = $resultsFileHandles{$lang};
			print $fh "$configNo\t$res\n";
		}
		if (-f $stopFile) {
			$self->{logger}->info("Stopping after config $configNoStr (last was ".($stopAtConfig-1).")");
			last;
		}
	}
	foreach my $lang (@{$self->{languages}}) {
		my $fh = $resultsFileHandles{$lang};
		close($fh);
	}
}


sub loadMetaFeaturesScores {
	my $self = shift;
	my $lang = shift;
	my $iterNo = shift;
	my $iterId=  sprintf("%0".$self->{nbDigitsIter}."d", $iterNo);
	my $f = $self->{workDir}."/iterations/$iterId/$lang/meta-features.scores";
	$self->{logger}->debug("Loading meta-features scores from $f");
	my $data = readConfigFile($f);
	my %res;
	while (my ($metaFeat, $featData) = each %$data) {
		$self->{logger}->trace("Reading meta-feature $metaFeat");
		my @pairs = split(";", $featData);
		foreach my $pair (@pairs) {
			my ($value, $sum, $nb, $max) = split(":",$pair);
			$self->{logger}->trace("Value $value: sum=$sum, nb=$nb, max=$max");
			$self->{logger}->logconfess("invalid format $pair") if (!defined($max));
			$res{$metaFeat}->{$value} = { "sum" => $sum, "nb" => $nb, "max" => $max };
		}
	}
	return \%res;
}

sub writeMetaFeaturesScores {
	my $self = shift;
	my $lang= shift;
	my $metaFeaturesScores = shift; # only ->{$lang}
	my $iterId = shift;
	my $f = $self->{workDir}."/iterations/$iterId/$lang/meta-features.scores";
	$self->{logger}->debug("Writing meta-features scores to $f");
	open(FILE, ">", $f) or $self->{logger}->logconfess("can not open  for writing");
	while (my ($metaFeat, $featData) = each %$metaFeaturesScores) {
		my @line;
		while (my ($value, $dataSNM) = each %$featData) {
			push(@line, "$value:".$dataSNM->{sum}.":".$dataSNM->{nb}.":".$dataSNM->{max});
		}
		my $content = "$metaFeat=".join(";", @line);
		$self->{logger}->trace("Writing meta-feature $metaFeat: content = '$content'");
		print FILE $content."\n";
	}
	close(FILE);
}



sub loadTestFileContent {
	my $self = shift;
	my $indexInTestFiles = shift;
#	my $name = shift;
	my $lang = shift;
	my $featuresTypes = shift;
	my $onlyTheseIndexes = shift; #OPTIONAL
	
	my $name = $self->{testSet}->{$lang}->[$indexInTestFiles]->{id};
	my %res;
	$self->{logger}->debug("Reading test data for id=$name, lang=$lang, indexInTestFiles=$indexInTestFiles, ft=$featuresTypes");
	foreach my $ft (@$featuresTypes) {
		my $f = $self->{dataDir}."/$lang/".$self->{learningParams}->{testDataFeaturesDir}."/$ft/$name";
		$self->{logger}->trace("Reading test data for feature type $ft from $f.count[/total]");
		my $content = readTSVByColumnsNoHeader("$f.count", "\t", 1, $self->{logger}, $onlyTheseIndexes);
		$res{$ft}->{"abs"} = $content->[1];
		$res{$ft}->{"rel"} = $content->[2];
#		if (! -f "$f.count.total") { # dirty trick
#		    $f = $self->{dataDir}."/$lang/features.0/$ft/$name";
#		}
		$content = readFileAsTokensList("$f.count.total", $self->{logger});
		$res{$ft}->{"distinct"} = $content->[0];
		$res{$ft}->{"total"} = $content->[1];
		$self->{logger}->logconfess("Undefined values for nb distinct and/or nb total in $f.count.total") if (!defined($res{$ft}->{"distinct"}) || !defined($res{$ft}->{"total"}));
	}
#	$self->{logger}->trace({filter=> \&Dumper, value=>\%res});
	return \%res;
}




1;
