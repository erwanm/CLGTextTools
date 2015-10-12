package Text::TextAnalytics::PAN13::Config;


use strict;
use warnings;
use Carp;
use Log::Log4perl qw(:levels);
use Text::TextAnalytics::Util qw/pickInList pickNAmongSloppy readConfigFile mean discretize selectMFValueCriterion pickInListProbas/;
use Text::TextAnalytics::PAN13::FeatDist;
use Data::Dumper;

our $VERSION = $Text::TextAnalytics::VERSION;

#use base 'Exporter';
#our @EXPORT_OK = qw/selectMFValueCriterion/;


my 	$algoLearnByType = { "Trees" => [ "J48", "J48b" ],
					"SVM" => [ "SMO", "SMO2", "SMO3", "SMO4", "SMO5", "SMO6", "SMO7", "SMO8", "SMO9", "SMO10", "SMO11" ],
					"LogisticReg" => [ "Logistic", "Logistic2", "Logistic3", "Logistic4" ],
					"Bayes" =>  [ "NaiveBayes", "NaiveBayes2" ]
};
my $algoLearnWithType;
my @algoTypes;
foreach my $algoType (keys %$algoLearnByType) {
	push(@algoTypes, $algoType);
	foreach my $algo (@{$algoLearnByType->{$algoType}}) {
		$algoLearnWithType->{$algo} = $algoType;
	}
}

my $categsSetsValues = ["superSets","atomic", "all"];
my $paramWeightIfUnseen = 1;
my $nbBinsNbFeatsByCateg = 5;

#
#
# params->{metaFeaturesArea}->{mfName}->{mfValue} = area
#
sub newRandom() {
	my ($class, $categories, $featuresTypes, $metaFeatures, $mfCriterion) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	$logger->debug("Creating new random config (mfCriterion=$mfCriterion, scalar(categories)=".scalar(@$categories).", scalar(featuresTypes)=".scalar(@$featuresTypes).")");
#	foreach my $p (keys %$defaultParams) {
#		$params->{$p} = $defaultParams->{$p} unless (defined($params->{$p}));
#	}
#	$logger->trace("Parameters:");
#	$logger->trace({ filter => \&Dumper, value => $params });
	$logger->logconfess("featuresTypes is undef") if (!defined($featuresTypes));
	$logger->logconfess("categories is undef") if (!defined($categories));
	$logger->logconfess("metaFeaturesArea is undef") if (!defined($metaFeatures));
	$logger->trace("Converting meta-features as weights");
	my $metaFeaturesAsWeights = convertMetaFeaturesToParametersWeights($metaFeatures, $mfCriterion, $categories, $featuresTypes, $logger);
	$logger->trace({ filter => \&Dumper, value => $metaFeaturesAsWeights});
	my $self = generateRandomConfig($metaFeaturesAsWeights, $categories, $featuresTypes);
	$self->{featuresTypes} = $featuresTypes;
	$self->{categories} = $categories;
	$logger->debug("Random config created:");
	$logger->debug({ filter => \&Dumper, value => $self });
	$self->{logger} = $logger;
	bless($self, $class);
	return $self;
}

sub newFromFile {
	my ($class, $filename) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	my $self;
	$logger->debug("Creating new random config from file $filename:");
	$self->{logger} = $logger;
	my $conf = readConfigFile($filename);
	$self->{categsSets}=$conf->{categsSets};
	$conf->{categsSets} = undef;
	$self->{algoLearn}=$conf->{algoLearn};
	$self->{algoLearnType}=$conf->{algoLearnType};
	$conf->{algoLearn} = undef;
	while (my ($pair, $distConf) = each %$conf ) {
		if (defined($distConf)) {
			my ($categ, $ft) = ($pair =~ m/^(.+)\.(.+)$/);
			$logger->debug("reading dist config $distConf for categ $categ; ft $ft, pair=$pair");
			$self->{distConfigsByCatFT}->{$categ}->{$ft} = Text::TextAnalytics::PAN13::FeatDist->newFromId($distConf);
		}
	}
	foreach my $categ (keys %{$self->{distConfigsByCatFT}}) {
		$self->{nbFeatsByCateg}->{$categ} = scalar(keys %{$self->{distConfigsByCatFT}->{$categ}});
	}
	$logger->trace("config created:");
	$logger->trace({ filter => \&Dumper, value => $self });
	bless($self, $class);
	return $self;
}

sub getMetaFeatures {
	my $self = shift;
	my @res;
	my $nbFeats;
	while (my ($categ, $categData) = each %{$self->{distConfigsByCatFT}}) {
	    $self->{logger}->debug("extracting MF for categ=$categ");
		while (my ($ft, $distConf) = each %$categData) {
		    $self->{logger}->debug("MF for categ=$categ, ft=$ft");
			my $resDist = $distConf->getMetaFeatures($categ, $ft);
			push(@res, @$resDist);
			push(@res, [ "FeatType", $ft ]);
			push(@res, [ "categFTPair" , $categ."-".$ft]);
		}
	    die "bug" if (!defined($self->{featuresTypes}));
		my $binNbFeatsCateg = discretize($self->{nbFeatsByCateg}->{$categ}, $nbBinsNbFeatsByCateg, 1, scalar(@{$self->{featuresTypes}})); 
		push(@res, [ "nbFeatsByCateg", $self->{nbFeatsByCateg}->{$categ} ]); 
		push(@res, [ "categBinNbFeaturesPair", "$categ-$binNbFeatsCateg" ]);
		$nbFeats+=$self->{nbFeatsByCateg}->{$categ};
	}
#	my $binNbFeatsGlobal = discretize($nbFeats,10,0,scalar(@{$self->{featuresTypes}}) * scalar(@{$self->{categories}}));
	my $algoType = $self->{algoLearnType};
#	push(@res, [ "binNbFeatsGlobal",  $binNbFeatsGlobal ]);
	push(@res, [ "categsSets",  $self->{categsSets} ]);
	push(@res, [ "algoLearn",  $self->{algoLearn} ]); 
	push(@res, [ "algoLearnType",  $algoType ]); 
#	push(@res, [ "algoTypeBinNbFeatsPair",  "$algoType-$binNbFeatsGlobal" ]); 
	$self->{logger}->trace("Extracted the following list of meta-features from config:");
	$self->{logger}->trace({ filter => \&Dumper, value => \@res });
	my $asHash  = metaFeaturesAsHash(\@res);
	$self->{logger}->trace("Synthetized meta-features into hash:");
	$self->{logger}->trace({ filter => \&Dumper, value => $asHash });
	return $asHash;
}


# if first iteration, metaFeatures = empty hash.
#
sub convertMetaFeaturesToParametersWeights {
	my $metaFeatures = shift;
	my $selectCriterion = shift;
	my $categories = shift;
	my $featuresTypes =  shift;
	my $logger =shift;

	$logger->debug("converting meta-features to weights, selectCriterion=$selectCriterion");
	my $res = Text::TextAnalytics::PAN13::FeatDist::convertMetaFeaturesToParametersWeights($metaFeatures, $selectCriterion, $categories, $featuresTypes, $logger);
	foreach my $cSet (@$categsSetsValues) {
		$res->{categsSets}->{$cSet} =  selectMFValueCriterion($metaFeatures->{categsSets},  $cSet,$selectCriterion) || $paramWeightIfUnseen; 
	}
	while (my ($learnType, $algos) = each %$algoLearnByType) {
		$res->{algoLearnType}->{$learnType} =  selectMFValueCriterion($metaFeatures->{algoLearnType},  $learnType, $selectCriterion) || $paramWeightIfUnseen;
		foreach my $algoLearn (@$algos) {
			$res->{algoLearnByType}->{$learnType}->{$algoLearn} = selectMFValueCriterion($metaFeatures->{algoLearn},  $algoLearn, $selectCriterion) || $paramWeightIfUnseen;
		} 
	}
	foreach my $categ (@$categories) {
		for (my $nbFeats=1; $nbFeats<=scalar(@$featuresTypes); $nbFeats++) {
			my $bin = discretize($nbFeats, $nbBinsNbFeatsByCateg, 1, scalar(@$featuresTypes));
			$res->{nbFeatsByCateg}->{$categ}->{$nbFeats} = selectMFValueCriterion($metaFeatures->{categBinNbFeaturesPair}, "$categ-$bin", $selectCriterion) || $paramWeightIfUnseen; 
		}
		foreach my $ft (@$featuresTypes) {
			$res->{featuresTypesByCateg}->{$categ}->{$ft} = selectMFValueCriterion($metaFeatures->{categFTPair}, "$categ-$ft", $selectCriterion) || $paramWeightIfUnseen;
		} 
	}


	return $res;	
}



sub generateRandomConfig {
	my $mfWeights = shift;
	my $categories = shift;
	my $featuresTypes= shift;
	my %res;
	$res{categsSets} = pickInListProbas($mfWeights->{categsSets});
	$res{algoLearnType} = pickInListProbas($mfWeights->{algoLearnType});
	$res{algoLearn} = pickInListProbas($mfWeights->{algoLearnByType}->{$res{algoLearnType}});
	do {
	    foreach my $categ (@$categories) {
			if (($res{categsSets} eq "all" )|| (($res{categsSets} eq "atomic") &&  ($categ =~ m/.+_.+/)) || (($res{categsSets} eq "superSets") &&  ($categ !~ m/.+_.+/))) { # if this is a pair age_gender category, it's not a superset
				my $nbFeatsCateg = pickInListProbas($mfWeights->{nbFeatsByCateg}->{$categ});
				$res{nbFeatsByCateg}->{$categ} = pickInListProbas($mfWeights->{nbFeatsByCateg}->{$categ});
				for (my $i=0; $i<$res{nbFeatsByCateg}->{$categ}; $i++) {
					my $ft;
					do {
						$ft  = pickInListProbas($mfWeights->{featuresTypesByCateg}->{$categ});
					} while (defined($res{distConfigsByCatFT}->{$categ}->{$ft})); # already selected #  TODO hopefully no infinite loop there, but...
					$res{distConfigsByCatFT}->{$categ}->{$ft} = Text::TextAnalytics::PAN13::FeatDist->newRandom($mfWeights, $categ, $ft);
				}
	    	}
	    }
    } while (scalar(keys %{$res{distConfigsByCatFT}})==0); # loop while 0 categories selected
	return \%res;
}




sub metaFeaturesAsHash {
	my $metaFeatsAsArray = shift;
	my %nbByMF;
#	print Dumper($metaFeatsAsArray);
	foreach my $mf (@$metaFeatsAsArray) {
#	    print "DEBUG $mf\n";
		my ($name, $value) = ($mf->[0], $mf->[1]);
		$nbByMF{$name}->{$value}++;  
	}
	return \%nbByMF;	
}

sub writeToFile {
	my $self = shift;
	my $f = shift;
	$self->{logger}->debug("Writing config to $f");
	open(FILE, ">", $f) or $self->{logger}->logconfess("can not write to '$f'");
	print FILE "categsSets=".$self->{categsSets}."\n";
	print FILE "algoLearn=".$self->{algoLearn}."\n";
	print FILE "algoLearnType=".$self->{algoLearnType}."\n";
	while (my ($categ, $distByFT) = each %{$self->{distConfigsByCatFT}} ) {
		while (my ($ft, $distConf) = each %$distByFT) {
			print FILE "$categ.$ft=".$distConf->getId()."\n";
		}
	}	
	close(FILE);
}



sub computePerf {
	my $self = shift;
	my $boss = shift; 
	my $lang = shift;
	my $prefixFileId = shift; # based on iterId + no of the config in the list + lang (prefix for weka intermediate/results files)
	my $distDir = shift; # OPTIONAL : if defined, calls readDistancesFromFiles to read the instances and then createArffAndRunWeka directly, otherwise calls "compute" which will computes all the distances
	my $configNoStr = shift; # ONLY if $distDir is defined 
	
	my $instances;
	my $testSetIds;
	if (defined($distDir)) {
	    $self->{logger}->debug("computing perfs 'save mem' version");
		$instances  = $self->readDistancesFromFiles($lang, $distDir, $configNoStr);
	    $testSetIds = $boss->{currentTestSetIds}->{$lang};
	} else {
	    $self->{logger}->debug("computing perfs 'classical' version");
		$instances = $self->computeDistances($boss, $lang, $boss->{currentTestSet}->{$lang});
	    my @l = (keys %{$boss->{currentTestSet}->{$lang}});
	    $testSetIds = \@l;
	}

	my $stdout = $self->createArffAndRunWeka($boss, $lang, $instances, $testSetIds, $prefixFileId, undef, undef);
	
	$self->{logger}->logconfess("Error: output contains too many lines: '".join("|",@$stdout)."'") if (scalar(@$stdout)>1);
	my $res;
	if ((scalar(@$stdout)==0) || ($stdout->[0] =~ m/^\s*$/)) {
		$self->{logger}->logwarn("Empty output from pan-learning.sh");
		$res = "NA";
	} else {
		$res = $stdout->[0];
		$self->{logger}->debug("Computed perf for config, result is $res");
		chomp($res);
		$res = "NA" if (!defined($res));
	} 
	return $res;

}


sub computeDistances { 
	my $self = shift;
	my $boss = shift; 
	my $lang = shift;
	my $testData = shift;
	my $loadOnTheFly = shift; # if true, testData is an array of test ids

	# compute distances
	$self->{logger}->debug("Computing distances for lang $lang");
	my %resByCatFT;
	foreach my $categ (keys %{$self->{distConfigsByCatFT}}) {
		foreach my $f (keys %{$self->{distConfigsByCatFT}->{$categ}}) {
			my $distConfig = $self->{distConfigsByCatFT}->{$categ}->{$f};
			$self->{logger}->debug("Computing distances for categ $categ, feature type $f");
			if ($loadOnTheFly) {
			    $resByCatFT{$categ}->{$f} = $distConfig->computeScoresLoadDataOnTheFly($boss, $lang, $categ, $f, $testData);
			} else {
			    $resByCatFT{$categ}->{$f} = $distConfig->computeScores($boss, $lang, $categ, $f, $testData);
			}
			$self->{logger}->trace("Distances for categ $categ, feature type $f: ");
			$self->{logger}->trace({ filter => \&Dumper, value => $resByCatFT{$categ}->{$f} });
		}
	}

	return \%resByCatFT;
}


sub computeDistancesForSingleCategAndWriteToFile {
	my $self = shift;
	my $boss = shift; 
	my $lang = shift;
	my $categ = shift;
	my $prefixFileId = shift; # something like $boss->{workDir}."/iterations/$iterId/$lang/distances/$categ/$configNoStr" 
	my $testIds = shift; # data not loaded yet

	$self->logger->logconfess("BUG UNDEF testIds") if (!defined($testIds));
	$self->logger->logconfess("BUG empty testIds") if (scalar(@$testIds)==0);
	# compute distances
	$self->{logger}->debug("Computing distances for lang $lang for single categ $categ");
	foreach my $ft (keys %{$self->{distConfigsByCatFT}->{$categ}}) { # avoid FT which are not in categ for this config
		my %testData;
		foreach my $testId (@$testIds) { # load only this FT for all test data
			$testData{$testId} = $boss->loadTestFileContent($testId, $lang, [$ft]);
		}
		$self->{logger}->debug("Loaded data for ".scalar(keys %testData)." test instances categ $categ, ft $ft");
		my $distConfig = $self->{distConfigsByCatFT}->{$categ}->{$ft};
		$self->{logger}->debug("Computing distances for categ $categ, feature type $ft");
		my $dists = $distConfig->computeScores($boss, $lang, $categ, $ft, \%testData);
		my $file = "$prefixFileId.$ft.dists";
		$self->{logger}->debug(" Writing distances for categ $categ, ft $ft to $file");
		open(OUT, ">", $file) or $self->{logger}->logconfess("can not open file $file for writing");
		while (my ($testId, $dist)= each %$dists) {
			print OUT "$testId=$dist\n";
		}
		close(OUT);
		$self->{logger}->trace("Distances for categ $categ, feature type $ft: ");
		$self->{logger}->trace({ filter => \&Dumper, value => $dists });
	}
	# save a file which marks the task as done
	my $file = "$prefixFileId.done";
	$self->{logger}->debug("Finished distances for categ $categ, writing 'done' file to $file");
	open(OUT, ">", $file) or $self->{logger}->logconfess("can not open file $file for writing");
	print OUT "done\n"; # useless
	close(OUT);
	
	# nothing to return.
}

sub readDistancesFromFiles  {
	my $self = shift;
#	my $boss = shift; 
	my $lang = shift;
	my $distDir = shift; # something like $boss->{workDir}."/iterations/$iterId/$lang/distances/" (left: "$categ/$configNoStr")
	my $configNoStr = shift;
	
	my %resByCatFT;
	foreach my $categ (keys %{$self->{distConfigsByCatFT}}) {
		foreach my $ft (keys %{$self->{distConfigsByCatFT}->{$categ}}) {
			my $file = "$distDir/$categ/$configNoStr.$ft.dists";
			$self->{logger}->debug("Reading distances for categ $categ, ft $ft from $file");
			$resByCatFT{$categ}->{$ft} = readConfigFile($file);
		}
	}

	return	\%resByCatFT;
}


sub createArffAndRunWeka {
	my $self = shift;
	my $boss = shift;
	my $lang = shift;
	my $instances = shift;
	my $testSetIds = shift;
	my $prefixFileId = shift;
	my $generateModelFilename = shift;
	my $applyModelFilename = shift;

#	my $testData = $boss->{currentTestSet}->{$lang};
	my $testData = $instances;
	my $globalTestDataLabels= $boss->{testSet}->{$lang};
	my @categories = grep { m/.+_.+/ } @{$boss->{categories}}; 

	# arff
	my $file = "$prefixFileId.input.arff";
	$self->{logger}->debug("Preparing file $file for weka (lang=$lang, categories=".join(";", @categories).") ") if ($self->{logger}->is_debug());
	open(OUT, ">", $file) or die "Can not create $file";
	print OUT "\@RELATION pan13\n\n";
	foreach my $categ (sort keys %{$self->{distConfigsByCatFT}}) {
		foreach my $ft (sort keys %{$self->{distConfigsByCatFT}->{$categ}}) {
	    print OUT "\@ATTRIBUTE F$categ.$ft NUMERIC\n";
		}
	}
	my @tmpCategs = map { "C$_" } (sort @categories); # IMPORTANT: PREFIX EVERY CLASS WITH 'C'
	my $categsAsNominal = "{ ".join(",",@tmpCategs)." }";
	print OUT "\@ATTRIBUTE class $categsAsNominal\n";
	print OUT "\n\@DATA\n";

	$self->{logger}->debug("Writing ".scalar(@$testSetIds)." instances to file $file (sorted by id)");
	foreach my $testId (sort @$testSetIds) {  # SORTED IN ORDER TO READ OUTPUT IF APPLYING MODEL
		# features
		my @features;
		foreach my $categ (sort keys %{$self->{distConfigsByCatFT}}) {
			foreach my $ft (sort keys %{$self->{distConfigsByCatFT}->{$categ}}) {
				my $score = $instances->{$categ}->{$ft}->{$testId};
				$self->{logger}->logconfess("score instances->{$categ}->{$ft}->{$testId} undefined") if (!defined($score));
				$score = "?" if (($score eq "NA") || ($score eq "nan") || ($score eq "inf") || ($score eq "-inf"));
				push(@features, $score);
			}
		}
		# label
		my $class;
		if (defined($applyModelFilename)) {
			$class = $tmpCategs[0]; # default dummy categ
		} else {
			$class = "C".$globalTestDataLabels->[$testId]->{ageGenderPair};
		}		
		print OUT join(",", @features).",$class\n";
	}
	close(OUT);

	# run weka
	my $algo = $self->{algoLearn};
	my $params ="";
	if (defined($applyModelFilename)) {
		$self->{logger}->debug("Option applyModel set to $applyModelFilename");
		$params .= "-a $applyModelFilename";
	} elsif (defined($generateModelFilename)) {
		$self->{logger}->debug("Option generateModel set to $generateModelFilename");
		$params .= "-g $generateModelFilename";
	}
#	my	$command = "pan-learning.sh $params -c ".$boss->{learningParams}->{nbFoldsWeka}."  $prefixFileId $algo 2>$prefixFileId.err |";
#	open(PIPE, $command) or $self->{logger}->logconfess("Something wrong, can not run the command pan-learning.sh");
#	my @stdout = <PIPE>; 
#	close(PIPE);
	my  $command = "pan-learning-wrapper.sh $prefixFileId.out $prefixFileId.err $params -c ".$boss->{learningParams}->{nbFoldsWeka}."  $prefixFileId $algo";
#	open(PIPE, $command) or $self->{logger}->logconfess("Something wrong, can not run the command pan-learning.sh");
#	my @stdout = <PIPE>; 
#	close(PIPE);
	my $timeout  = $boss->{learningParams}->{timeOutWeka};
	my @stdout;
	$self->{logger}->debug("Starting weka process with command='$command' ; timeout=$timeout");
	eval {
	    local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	    alarm $timeout;
	    system($command);
	    alarm 0;
	};
	if ($@) {
		if ($@ eq "alarm\n") {
		    $self->{logger}->logwarn("Command $command timed out after $timeout sec");
		} else {
		    $self->{logger}->logwarn("Command $command exited with errors: $@");
		}
#	    die unless $@ eq ;   # propagate unexpected errors
	    # timed out
	}
	else {
        # didn't
		$self->{logger}->debug("Weka process seems to have returned normally");
	    open(FILE, "<", "$prefixFileId.out") or $self->{logger}->logconfess("Can not open $prefixFileId.out");
	    @stdout = <FILE>;
	    close(FILE);
	    open(FILE, "<", "$prefixFileId.err") or $self->{logger}->logconfess("Can not open $prefixFileId.err");
	    my @checkErr = <FILE>;
	    close(FILE);
	    $self->{logger}->logwarn("error file $prefixFileId.err from pan-learning.sh is not empty") if (scalar(@checkErr) >0);
	}
	
	return \@stdout;
}


sub selectConfigs {
	my $configsAndMF = shift;
	my $metaFeaturesScores = shift;
	my $nbConfigsToSelect = shift;
	my $metaFeaturesSelection = shift; # mean or max
	my $configsDir = shift;
#	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
# TEMPORARY
	my $logger = Log::Log4perl->get_logger(__PACKAGE__.".selectConfigs");
	

	$logger->trace("Current meta-features scores:");
	$logger->trace({filter=> \&Dumper, value=> $metaFeaturesScores});
	my %mfScoresById;
	$logger->debug("Selecting configs: computing meta-features expected scores by config");
	my $nbUnseenPairs=0;
	my %unseen;
	for (my $i=0; $i<scalar(@$configsAndMF); $i++) {
		while (my ($name, $mfValues) = each %{$configsAndMF->[$i]->{metaFeatures}}) {
			my ($accu, $nbValues) = (0,0);
			while (my ($value, $nbThis) = each %$mfValues) {
				my $dataNV = $metaFeaturesScores->{$name}->{$value};
				if (defined($dataNV)) {
#				    $logger->trace("Found score for MF $name=$value, i=$i");
					if ($metaFeaturesSelection eq "mean") {
						my $mean = $dataNV->{sum} / $dataNV->{nb};
						$accu += ($mean * $nbThis);
						$nbValues += $nbThis;
					} elsif ($metaFeaturesSelection eq "max") {
						$accu += ($dataNV->{max} * $nbThis);
						$nbValues += $nbThis;
					} else {
						$logger->logconfess("bug, invalid id $metaFeaturesSelection in selectConfigs");
					}
				} else {
				    $logger->trace("No score for MF $name=$value, i=$i");
				    if (defined($unseen{$name}->{$value})) {
					push(@{$unseen{$name}->{$value}}, $i);
				    } else {
					$unseen{$name}->{$value} = [ $i ];
				    }
				    $nbUnseenPairs++;
					$nbValues = 0;
					last;
				}	
			}
#			$mfScoresById{$name}->[$i] = ($nbValues==0) ? 1 : $accu / $nbValues; # max for unknown mf/value
			if ($nbValues>0) {
			    $mfScoresById{$name}->[$i] = $accu / $nbValues;
			} else {
#			    $mfScoresById{$name}->[$i] = ($unseen{$name}->{$value}==1) ? 1 : 0; # to avoid setting multiple "1" scores and selecting multiple times the same MF pair. the priority during the first iterations is to assing a value to every pair quiclky. CHANGED
			    $mfScoresById{$name}->[$i] = 0;
			}
	#		$logger->trace("mfScoresById{$name}->[$i]=".$mfScoresById{$name}->[$i]);
		}

	}
	$logger->debug("selection based on MF: $nbUnseenPairs unseen pairs, ".scalar(keys %unseen)." unseen MF names among ".scalar(keys %$metaFeaturesScores).". Detail:");
#	$logger->debug({filter=>\&Dumper, value=>\%unseen});

	# additional step for unseen pairs: for each pair, select the one which has the best average (would be too complex to do the voting stuff)
	my %bestUnseen;
	while (my ($mf, $configsUnseenByValue) = each %unseen) {
	    $logger->debug("".scalar(keys %$configsUnseenByValue)." unseen distinct pairs for MF $mf.");
	    while (my ($value, $configsIds) = each %$configsUnseenByValue) {
		$logger->trace("$mf , $value : ".scalar(@$configsIds)." configs");
		my ($maxVal, $maxId);
		foreach my $confId (@$configsIds) {
		    my ($thisSum, $thisNb) = (0,0);
		    foreach my $mf2 (keys %{$configsAndMF->[$confId]->{metaFeatures}}) {
			$thisSum  += $mfScoresById{$mf2}->[$confId];
			$thisNb++;
		    }
		    if (!defined($maxVal) || ($thisSum / $thisNb > $maxVal)) {
			$maxVal = $thisSum / $thisNb;
			$maxId = $confId;
		    }
		}
		$bestUnseen{$maxId} = 1; # drop the mf/value, we don't need it anymore, but put as hash key so that the same config is not included twice.
		$logger->trace("pair $mf/$value : selected config $maxId (maxVal=$maxVal)");
	    }
	}
	my @selectedIds;
	my @selectedUnseen = (keys %bestUnseen);
	my $nbUnseenSelected = scalar(@selectedUnseen);
	$logger->debug("$nbUnseenSelected configs containing at least one of the unseen distinct MF pairs are selected");
	if ($nbUnseenSelected >= $nbConfigsToSelect) {
	    $logger->debug("$nbUnseenSelected > $nbConfigsToSelect configs to select, returning only 'unseen' configs");
	    @selectedIds = @selectedUnseen[0..$nbConfigsToSelect-1];
	} else {
	    $nbConfigsToSelect-= $nbUnseenSelected; # Warning, modifying the value!
	    $logger->debug("$nbUnseenSelected unseen: $nbConfigsToSelect left to select by voting");

	    my %rankingsByMF;
	    $logger->debug("Ranking config ids by score for every meta-feature, and extracting the $nbConfigsToSelect best");
	    while (my ($mf, $configsMFScores) = each %mfScoresById) {
		my @completedMFSCores = map { defined($configsMFScores->[$_]) ? $configsMFScores->[$_] : 0 } (0..scalar(@$configsAndMF)-1); # replacing undef values which correspond to cases where the config does not have any MF name (e.f. filter)
#	    $logger->trace("completedMFSCores content:");
#	    $logger->trace({filter=> \&Dumper, value=> \@completedMFSCores});
		my @sortedIds = sort { $completedMFSCores[$b] <=> $completedMFSCores[$a] } (0..scalar(@$configsAndMF)-1);
		my @bestN = @sortedIds[0..$nbConfigsToSelect-1];
		if ($logger->is_trace()) {
		    my @maxScoresMF = map { $completedMFSCores[$_] } @bestN;
		    my @minScoresMF = map { $completedMFSCores[$_] } @sortedIds[(scalar(@sortedIds)-$nbConfigsToSelect)..(scalar(@sortedIds)-1)];
		    $logger->trace("$nbConfigsToSelect best scores for MF $mf:");
		    $logger->trace({filter=>\&Dumper,value=>\@maxScoresMF});
		    $logger->trace("$nbConfigsToSelect worst scores for MF $mf:");
		    $logger->trace({filter=>\&Dumper,value=>\@minScoresMF});
		}
		$rankingsByMF{$mf} = \@bestN;
	    }
	    # voting
	    my %votesByConfig;
	    $logger->debug("Computing votes of meta-features by config (only for configs which appear in the $nbConfigsToSelect best of at least one meta-feature)");
	    while (my ($mf, $bestN) = each %rankingsByMF) {
		for (my $rank=0; $rank<$nbConfigsToSelect; $rank++) {
		    my $confId = $bestN->[$rank];
		    $votesByConfig{$confId} += ($nbConfigsToSelect - $rank) / $nbConfigsToSelect; # weighted vote (?)
# NO WRONG		    $votesByConfig{$confId}->{nb}++;
		}
	    }
	    foreach my $confId (keys %votesByConfig)  {
		$votesByConfig{$confId} /= scalar(keys %{$configsAndMF->[$confId]->{metaFeatures}}); # avg (normalize by number of MF names for this conf, because some confs have more (e.g. with/witout filter))
	    }
	    my @selectedIdsAll = sort { $votesByConfig{$b} <=> $votesByConfig{$a} } (keys %votesByConfig);
	    writeRanksConfigs($configsDir, \@selectedIds, \%mfScoresById, \%rankingsByMF, $logger);

	    @selectedIds = (keys %bestUnseen); # merge the "unseen" selected and the "voted" ones
	    for (my $indexVotes=0; $indexVotes<scalar(@selectedIdsAll) && ($nbConfigsToSelect>0); $indexVotes++) {
		if (!defined($bestUnseen{$selectedIdsAll[$indexVotes]})) { # in case a config is both is unseen and selected by votes
		    $nbConfigsToSelect--;
		    push(@selectedIds,$selectedIdsAll[$indexVotes]);
		}
	    }
	    $logger->trace("Selected ids (unseen+voted)");
	    $logger->trace({filter=>\&Dumper, value=> \@selectedIds});
	}


	$logger->debug("Extracting the selected configs and their respective meta-features");
	my @selectedConfigsAndMF = map {$configsAndMF->[$_]} @selectedIds;

	return \@selectedConfigsAndMF;
}

sub writeRanksConfigs {
	my $dir = shift;
	my $selectedIds = shift;
	my $mfScoresById = shift;
	my $rankingsByMF = shift;

	my $logger = Log::Log4perl->get_logger(__PACKAGE__);

	my $nbDigitsConfig = length(scalar(@$selectedIds));

#			my $rank = $rankingsByMF->{$id0}
# TODO write n-best by mf with configs id
	
	$logger->debug("Writing meta-features scores and (possibly) rank for each selected config");
	for (my $id=0; $id < scalar(@$selectedIds); $id++) {
		my $idStr = sprintf("%0".$nbDigitsConfig."d", $id);
		my $id0 = $selectedIds->[$id];
		my $f = "$dir/$idStr.ranks";
		open(FILE, ">", $f) or $logger->logconfess("cannot write to '$f'");
		while (my ($mf, $configsMFScores) = each %$mfScoresById) {
			my $score  = $configsMFScores->[$id0];
			$score = "undef" if (!defined($score));
			print FILE "$mf\t$score\n";
		}
		close(FILE);
	} 
}


sub scoreMetaFeatures {
	my $configsAndMF = shift;
	my $configsScores = shift;
	my $metaFeaturesScores = shift || {};
#	my $logger = Log::Log4perl->get_logger(__PACKAGE__); 
	my $logger = Log::Log4perl->get_logger(__PACKAGE__.".selectConfigs");
	
	$logger->trace({filter=>\&Dumper, value=>$configsScores});
	my %accuByMF;
	my %totalByMF;
	$logger->debug("Computing new meta-features scores and updating old ones");
	$logger->trace({filter=>\&Dumper, value=>$configsScores});
	for (my $i=0; $i<scalar(@$configsAndMF); $i++) {
	    my $score = $configsScores->{$i}; 
	    if (defined($score)) { # possible that a score has not been computed if parallel + stop before end - ignore it
		$logger->debug("score=$score for config $i");
		$score = 0 if ($score eq "NA");
		while (my ($name, $mfValues) = each %{$configsAndMF->[$i]->{metaFeatures}}) {
		    $logger->trace("MF $name");
		    if (scalar(keys %$mfValues)==0) {
			$logger->trace({filter=>\&Dumper,value=>$configsAndMF->[$i]});
			die "BUGGGGGG" ;
		    }
		    while (my ($value, $nb) = each %$mfValues) {
			$logger->logconfess("bug: undef nb ") if (!defined($nb));
			$logger->trace("MF $name: $value x $nb in mfValues");
			if (defined($metaFeaturesScores->{$name}->{$value})) {
			    $metaFeaturesScores->{$name}->{$value}->{sum} += ($nb * $score);
			    $metaFeaturesScores->{$name}->{$value}->{nb} += $nb;
			    $metaFeaturesScores->{$name}->{$value}->{max} = $score if ($score > $metaFeaturesScores->{$name}->{$value}->{max});
			} else {
			    $metaFeaturesScores->{$name}->{$value}->{sum} = ($nb * $score);
			    $metaFeaturesScores->{$name}->{$value}->{nb} = $nb;
			    $metaFeaturesScores->{$name}->{$value}->{max} = $score;
			}
		    }	
		}
	    }
	}
	$logger->trace("New meta-features:");
	$logger->trace({filter=>\&Dumper, value=>$metaFeaturesScores});
	return $metaFeaturesScores;
}


sub writeConfigs {
	my $configsAndMF = shift;
	my $dir = shift;

	my $logger = Log::Log4perl->get_logger(__PACKAGE__);

	my $nbDigitsConfig = length(scalar(@$configsAndMF));
#	print "DEBUG nb=$nbDigitsConfig\n";
	for (my $i=0; $i<scalar(@$configsAndMF); $i++) {
		my $configNoStr = sprintf("%0".$nbDigitsConfig."d", $i);
		my $f = "$dir/$configNoStr.conf";
		$configsAndMF->[$i]->{config}->writeToFile($f);
	}
	
}


1;
