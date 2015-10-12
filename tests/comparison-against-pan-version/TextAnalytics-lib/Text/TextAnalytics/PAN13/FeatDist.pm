package Text::TextAnalytics::PAN13::FeatDist;


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Math::Trig;
use Math::CDF;
use Text::TextAnalytics::Util qw/pickInList pickNAmongSloppy mean geomMean harmoMean selectMFValueCriterion pickInListProbas/;
use Data::Dumper;
use Text::TextAnalytics::PAN13::FeatSelect;
#use Text::TextAnalytics::PAN13::Config qw/selectMFValueCriterion/;

my $paramWeightIfUnseen = 1; # not good



our $VERSION = $Text::TextAnalytics::VERSION;

my $simpleColumns = ["mean", "median"];
my $meanTypes = [ "arithm", "geom", "harmon" ];
my $paramsByDistName = {
		       "euclidean" => { "column" => $simpleColumns },
			   "cosine" => { "column" => $simpleColumns },
			   "chi2" => { "column" => $simpleColumns },
			   "jaccard" => { "column" => $simpleColumns },
			   "area" => { "area" => [ "mean", "median", "stdDev", "minMax", "Q1Q3" ],
			   			   "normalized" => [0,1],
			   			   "meanType" => $meanTypes
			   		     }, 
			   "probaNormal" => { "type" => [ "CDF", "PDF" ],
			   					  "standard" => [ 0, 1 ],
			   			          "meanType" => $meanTypes
			   		            } 
};

sub newRandom() {
	my ($class, $mfWeights, $categ, $ft) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	my $self;
#	foreach my $p (keys %$paramsByDistName) {
#		$params->{$p} = $paramsByDistName->{$p} unless (defined($params->{$p}));
#	}
	$self = generateRandomConfig($mfWeights, $categ, $ft, $logger);
	$self->{logger} = $logger;
	bless($self, $class);
	return $self;
}


sub newFromId {
	my ($class, $id) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	my $self;
	$logger->debug("new dist from id=$id");
	$self->{logger} = $logger;
	my @items = split ("_", $id);
	my $distId = pop(@items);
	$logger->trace("extracted distId=$distId");
	$self->{selectConfig} = Text::TextAnalytics::PAN13::FeatSelect->newFromId(\@items);
	$self->{dist} = distFromId($distId,$logger);
	$logger->trace("returning object");
	$logger->trace({ filter=>\&Dumper, value =>$self});
	bless($self, $class);
	return $self;
}


sub getMetaFeatures {
	my $self = shift;
	my $categ = shift;
	my $ft =  shift;
	
	my $dist = $self->{dist};
	my $resSelect =  $self->{selectConfig}->getMetaFeatures($categ, $ft, $dist->{name});
	my @res =@$resSelect;
#	push(@res, [ "distName", $dist->{name} ]);
	push(@res, [ "featTypeDistNamePair", $ft."-".$dist->{name} ]);
	if (defined($dist->{column})) {
#		push(@res, [ "distCol", $dist->{column} ]) ;
		push(@res, [ "distNameColPair", $dist->{name}."-".$dist->{column} ]) if (defined($dist->{column}));
		push(@res, [ "featTypeDistColPair", $ft."-".$dist->{column} ]);
	}
	if (($dist->{name} eq "area") || ($dist->{name} eq "probaNormal")) {
		my $id = ($dist->{name} eq "area") ? $dist->{area} : $dist->{type};
		my $std = ($dist->{name} eq "area") ? $dist->{normalized} : $dist->{standard} ;
		push(@res, [ "featTypeDistAreaTypePair", "$ft-$id" ]);
		push(@res, [ "distAreaTypeMeanTypePair", $id."-".$dist->{meanType}]);
		push(@res, [ "distAreaTypeStdNormaPair", $id."-".$std]);
#		push(@res, [ "distAreaNorma", $dist->{area}."-".$dist->{normalized} ]) if ($dist->{name} eq "area");
#		push(@res, [ "distProbaStd", $dist->{type}.".".$dist->{standard} ]) if ($dist->{name} eq "probaNormal");
	}
	$self->{logger}->trace("Meta features for distance:");
	$self->{logger}->trace({filter=>\&Dumper, value => \@res});
	return \@res;
}


sub convertMetaFeaturesToParametersWeights {
	my $metaFeatures = shift;
	my $selectCriterion = shift;
	my $categories = shift;
	my $featuresTypes =  shift;
	my $logger= shift;

	my @distNames = (keys %$paramsByDistName);
	my $res = Text::TextAnalytics::PAN13::FeatSelect::convertMetaFeaturesToParametersWeights($metaFeatures, $selectCriterion, $categories, $featuresTypes, \@distNames, $logger);
	foreach my $distName (@distNames) {
		foreach my $ft (@$featuresTypes) {
			$res->{distNameByFT}->{$ft}->{$distName}  = selectMFValueCriterion($metaFeatures->{featTypeDistAreaTypePair},  "$ft-$distName", $selectCriterion) || $paramWeightIfUnseen;
		}
		if (($distName eq "area")  || ($distName eq "probaNormal")) {
		 
			my @areaType = @{$paramsByDistName->{$distName}->{ ($distName eq "area") ? "area" : "type" }};
			foreach my $areaType (@areaType) {
				foreach my $ft (@$featuresTypes) {
					$res->{areaTypeByDistNameAndFT}->{$distName}->{$ft}->{$areaType}  = selectMFValueCriterion($metaFeatures->{featTypeDistNamePair},  "$ft-$areaType", $selectCriterion) || $paramWeightIfUnseen;
				}
				foreach my $meanType (@$meanTypes) {
					$res->{meanTypeByDistNameAndAreaType}->{$distName}->{$areaType}->{$meanType} = selectMFValueCriterion($metaFeatures->{distAreaTypeMeanTypePair},  "$areaType-$meanType", $selectCriterion) || $paramWeightIfUnseen;
				}
				foreach my $stdNorma (0,1) {
					$res->{stdNormaByDistNameAndAreaType}->{$distName}->{$areaType}->{$stdNorma} = selectMFValueCriterion($metaFeatures->{distAreaTypeStdNormaPair},  "$areaType-$stdNorma", $selectCriterion) || $paramWeightIfUnseen;
				}
			}
		} else {
			foreach my $ft (@$featuresTypes) {
				foreach my $col (@$simpleColumns) {
					my $valDistName = selectMFValueCriterion($metaFeatures->{distNameColPair},  "$distName-$col", $selectCriterion) || $paramWeightIfUnseen;
					my $valFT = selectMFValueCriterion($metaFeatures->{featTypeDistColPair},  "$ft-$col", $selectCriterion) || $paramWeightIfUnseen;
					$res->{distColByFTAndDistName}->{$ft}->{$distName}->{$col} = ($valDistName + $valFT) / 2 ;
				}
			}
		}
	}
	return $res;
}



sub generateRandomConfig {
	my ($mfWeights, $categ, $ft, $logger)  = @_;
	my %res;
	do {
		my $distName = pickInListProbas($mfWeights->{distNameByFT}->{$ft});
		$res{dist}->{name} = $distName;
		if ($distName eq "area") {
			$res{dist}->{area} = pickInListProbas($mfWeights->{areaTypeByDistNameAndFT}->{$distName}->{$ft});
			$res{dist}->{meanType} = pickInListProbas($mfWeights->{meanTypeByDistNameAndAreaType}->{$distName}->{$res{dist}->{area}});
			$res{dist}->{normalized} = pickInListProbas($mfWeights->{stdNormaByDistNameAndAreaType}->{$distName}->{$res{dist}->{area}});
		} elsif ($distName eq "probaNormal") {
			$res{dist}->{type} = pickInListProbas($mfWeights->{areaTypeByDistNameAndFT}->{$distName}->{$ft});
			$res{dist}->{meanType} = pickInListProbas($mfWeights->{meanTypeByDistNameAndAreaType}->{$distName}->{$res{dist}->{type}});
			$res{dist}->{standard} = pickInListProbas($mfWeights->{stdNormaByDistNameAndAreaType}->{$distName}->{$res{dist}->{type}});
		} else {
			$res{dist}->{column} = pickInListProbas($mfWeights->{distColByFTAndDistName}->{$ft}->{$distName});
		}
	} while (!acceptableConfig(\%res));
	$res{selectConfig} = Text::TextAnalytics::PAN13::FeatSelect->newRandom($mfWeights, $categ, $ft, $res{dist}->{name});
	return \%res;
}


sub distFromId {
	my $id = shift;
	my $logger = shift;
	my %res;
	my @pieces = split("-", $id);
	$res{name} = shift(@pieces);
#	$logger->debug("distFromId: pieces = ".join(" ; ", @pieces));
	foreach my $p (sort keys %{$paramsByDistName->{$res{name}}}) {
		$res{$p} = shift(@pieces);
#		$logger->debug("$p => $res{$p}");
	}
	return \%res;
}

sub getId {
	my $self = shift;
	return $self->{selectConfig}->getId()."_".$self->getDistId();
}


sub getDistId {
	my $self = shift;
	my $res = $self->{dist}->{name};
	foreach my $p (sort keys %{$self->{dist}}) {
			$res .= "-".$self->{dist}->{$p} if ($p ne "name");
	}
	return $res;
}	


sub acceptableConfig {
	my $config = shift;
	return 0 if (($config->{dist}->{name} eq "probaNormal") && ($config->{dist}->{type} eq "CDF") &&  !$config->{dist}->{standard});
	return 0 if (($config->{dist}->{name} eq "area") && ($config->{dist}->{area} eq "s") &&  !$config->{dist}->{standard});
	return 1;
}


# for only one config
sub computeScoresLoadDataOnTheFly {
    my $self = shift;
    my $boss = shift;
    my $lang = shift;
    my $categ =shift;
    my $ft = shift;
    my $testDataIds = shift;

    my %res;
    my $ftArray = [ $ft ];
    
    # dirty
    $self->{logger}->debug("Loading ref data for categ=$categ, ft=$ft in boss->{stats}->{$lang}->{$categ}->{$ft}");
    $boss->{stats}->{$lang} = Text::TextAnalytics::PAN13::APTrainingSystem::loadAllStats($boss->{dataDir}."/$lang", [ $categ ], $ftArray, $self->{logger});
    my $indexes = $self->{selectConfig}->getIndexes($boss, $lang, $categ, $ft);
    foreach my $testId (@$testDataIds) {
	my $testDataThisId = $boss->loadTestFileContent($testId, $lang, $ftArray, $indexes);
	my $res0 = $self->computeScores($boss, $lang, $categ, $ft, { $testId => $testDataThisId }, $indexes); # returns a hash { $testId => score }
	$res{$testId} = $res0->{$testId};
    }
    $boss->{stats}->{$lang}->{$categ}->{$ft} = undef;
    return \%res;
}


sub computeScores { 
	my $self = shift;
	my $boss = shift; 
	my $lang = shift;
	my $categ = shift;
	my $ft = shift;
	my $testData = shift; # hash by index
	my $indexes = shift; # OPTIONAL

	my %res; # hash by test file index


	my $distName = $self->{dist}->{name};
	$self->{logger}->debug("computing distances with $distName for config ".$self->getId()."") if ($self->{logger}->is_debug());
	$indexes = $self->{selectConfig}->getIndexes($boss, $lang, $categ, $ft) if (!defined($indexes));
	my $distCol = $self->{dist}->{column}; # only for chi2, euclid, cosine
	my $absRel = "rel";
#	my $absRel = ($distName eq "chi2") ? "abs" : "rel";
	# WARNING loading always relative values for ref data, but (only in case this is chi2) absolute value for probe
	my $refData = $boss->{stats}->{$lang}->{$categ}->{$ft}->{"rel"}; # all columns, all lines
	$boss->{logger}->logconfess("Data has not been loaded! was looking for boss->{stats}->{$lang}->{$categ}->{$ft}->{$absRel}") unless (defined($refData));
#	my $testData = $boss->{currentTestSet}->{$lang}; # hash by index # OLD
	if (scalar(keys %$testData)==0) {
	    $self->{logger}->logwarn("BUG 0 instances in test data ") ;
	    $self->{logger}->info( {filter => \&Dumper, value => $testData } ) ;
	    $self->{logger}->logconfess("BUG 0 instances in test data ") ;
	}
	$self->{logger}->trace("Test data: ".scalar(keys %$testData)." instances" );
#	$self->{logger}->trace({filter=>\&Dumper, value=>$testData});

	# ok if 0 indexes: just return NA for all test instances
	if (scalar(@$indexes)==0) {
	    $self->{logger}->debug("Config ".$self->getId().": the selection returned 0 indexes, returning NA for all test instances");
	    my %res;
	    foreach my $testId (keys %$testData) {
		$res{$testId} = "NA";
	    }
	    return \%res;
	}

	my %allScores; # allScores{testIndex}-> ... depends on the dist 
	for my $index (@$indexes) {
		if ($distName eq "probaNormal") {
			my $refSD = $refData->{"stdDev"}->[$index];
			my $std = $self->{dist}->{standard};
			my $isPDF;
			if ($self->{dist}->{type} eq "CDF") {
				$isPDF = 0;
			} elsif ($self->{dist}->{type} eq "PDF") {
				$isPDF = 1;
			} else {
				$self->{logger}->logconfess("Invalid type for probaNormal: ".$self->{dist}->{type});
			}
			if (($refSD ne "NA") && ($refSD !~ m/inf/) && ($refSD != 0)) {
				my $mean = $refData->{"mean"}->[$index];
				my $variance = $refSD**2;
				my ($testId, $testDataThisId);
				while ( ($testId, $testDataThisId) = each %$testData) {
					my $probeValue = $testDataThisId->{$ft}->{"rel"}->[$index];
					my ($thisMean, $thisVariance) = ($mean,$variance); 
					if ($std) {
						$probeValue = ($probeValue - $mean) / $variance;
						$thisMean=0;
						$thisVariance=1;
					}
					my $val;
				    if ($isPDF) {
						$val = 1 / sqrt( 2 * pi * $thisVariance) * exp( ($probeValue - $thisMean)**2 / (-2 * $thisVariance));
					} else {
						$probeValue = $thisMean - ($probeValue-$thisMean) if ($probeValue > $thisMean);
						$val = &Math::CDF::pnorm($probeValue);
					}
					push(@{$allScores{$testId}}, $val);
				}
			} else {
				foreach my $testId (keys %$testData) { # probably useless since the means will ignore NA values
					push(@{$allScores{$testId}}, "NA");
				}
			}
		} elsif  ($distName eq "area") {
			my $area = $self->{dist}->{area};
			my $normalize = $self->{dist}->{normalized};
			my $refMean = $refData->{"mean"}->[$index];
			my $refMedian = $refData->{"median"}->[$index];
			my $refStdDev = $refData->{"stdDev"}->[$index];
			my $refQ1 = $refData->{"Q1"}->[$index];
			my $refQ3 = $refData->{"Q3"}->[$index];
			my $refMin = $refData->{"min"}->[$index];
			my $refMax = $refData->{"max"}->[$index];
			my ($testId, $testDataThisId);
			while ( ($testId, $testDataThisId) = each %$testData) {
				my $probeValue = $testDataThisId->{$ft}->{"rel"}->[$index];
				my $val;
				if (($area eq "mean") || ($area eq "median")) {
					my $ref = ($area eq "mean") ? $refMean : $refMedian ;
					$val = abs($probeValue - $ref);
		  		 	$val = ($ref != 0) ? $val/$ref : undef if ($normalize);
				} elsif ($area eq "stdDev") {
					$val = abs($probeValue - $refMean);
		  		 	$val = ($refStdDev != 0) ? $val/$refStdDev : undef if ($normalize);
		  		 	$val = ($val<=1) ? 0 : $val-1 if (defined($val));
				} elsif ($area eq "minMax") {
				    if ($probeValue < $refMin) {
						$val =  $refMin - $probeValue ;
						$val = ($refMin != 0) ? $val / $refMin : undef if ($normalize);
		    		} elsif ($probeValue > $refMax) {
						$val =  $probeValue - $refMax;
						$val = ($refMax != 0) ? $val / $refMax : undef if ($normalize);
		    		} else {
		    			$val=0;
		    		} 
				} elsif ($area eq "Q1Q3") {
				    if ($probeValue < $refQ1) {
						$val =  $refQ1 - $probeValue ;
						$val = ($refQ1 != 0) ? $val / $refQ1 : undef if ($normalize);
		    		} elsif ($probeValue > $refQ3) {
						$val =  $probeValue - $refQ3;
						$val = ($refQ3 != 0) ? $val / $refQ3 : undef if ($normalize);
		    		} else {
		    			$val=0;
		    		} 
				} else {
					$self->{logger}->logconfess("Invalid 'area' value : '$area'");
				}
				$val = "NA" if (!defined($val));
				push(@{$allScores{$testId}}, $val);
			}
		} else { # euclid, chi, cosine, jaccard
			my $refValue = $refData->{$distCol}->[$index];
			my ($testId, $testDataThisId);
			while ( ($testId, $testDataThisId) = each %$testData) {
			    my $probeValue = $testDataThisId->{$ft}->{$absRel}->[$index];
			    if ($distName eq "jaccard") {
				$allScores{$testId}->{nb} = 0 if (!defined($allScores{$testId}->{nb}));
				$allScores{$testId}->{total}++;
			    	if (($refValue>0) && ($probeValue>0)) {
				    $allScores{$testId}->{nb}++;
			    	}
			    } elsif ($distName eq "euclidean") {
					$allScores{$testId} += ($refValue - $probeValue)**2;
			    } elsif ($distName eq "cosine") {
					$allScores{$testId}->{dotProd} += $refValue * $probeValue;
					$allScores{$testId}->{norms}->[0] += $refValue**2;;
					$allScores{$testId}->{norms}->[1] += $probeValue**2;;
			    } elsif ($distName eq "chi2") {
			    	my $totalProbe = $testDataThisId->{$ft}->{"total"};
				die "BUG: chi2 undef total for ft $ft, id $testId" if (!defined($totalProbe));
					my $expected = $refValue * $totalProbe ; # remark: refValue is a relative frequency, whereas probeValue is an absolute value # NOT TRUE ANYMORE, BOTH REL
					my $observed = $probeValue * $totalProbe;
					my $res = ($expected != 0) ? ($observed -  $expected)**2 / $expected : "NA";
	    			push(@{$allScores{$testId}}, $res);
			    } else {
			    	$self->{logger}->loconfess("invalid dist name = $distName");
			    }
			}
		}
		
	}
	$self->{logger}->logconfess("BUG: test set contains ".scalar(keys %allScores)." instances but only ".scalar(keys %$testData)."  series of scores were computed") if (scalar(keys %allScores) != scalar(keys %$testData));
	
	# compute final score
	foreach my $testId (keys %allScores) {
		if (($distName eq "probaNormal") || ($distName eq "area")) {
			if ($self->{dist}->{meanType} eq "arithm") {
				$res{$testId} = mean($allScores{$testId}, "NA");
			} elsif ($self->{dist}->{meanType} eq "geom") {
				$res{$testId} = geomMean($allScores{$testId}, "NA");
			} elsif ($self->{dist}->{meanType} eq "harmon") {
				$res{$testId} = harmoMean($allScores{$testId}, "NA");
			} else {
				$self->{logger}->logconfess("Invalid meanType: ".$self->{dist}->{meanType});
			}
		} elsif ($distName eq "jaccard") {
		    $res{$testId} = ($allScores{$testId}->{total}>0) ? $allScores{$testId}->{nb} / $allScores{$testId}->{total} : "NA"; 
		    $self->{logger}->debug("DEBUG JACCARD: $res{$testId}");
		} elsif ($distName eq "euclidean") {
			$res{$testId} = sqrt($allScores{$testId});
		} elsif ($distName eq "cosine") {
			my $norms = $allScores{$testId}->{norms};
			if (($norms->[0] != 0) && ($norms->[1] != 0) ) {
			    $res{$testId} = 1 - ($allScores{$testId}->{dotProd} / (sqrt($norms->[0]) * sqrt($norms->[1])));
			} else {
		    	$res{$testId} = "NA";
			}
		} elsif ($distName eq "chi2") {
			$res{$testId} = mean($allScores{$testId},"NA");
		}
		$self->{logger}->logconfess("Distance score for lang=$lang, categ=$categ, ft=$ft, test id $testId is not defined") if (!defined($res{$testId}));
		$self->{logger}->trace("Distance score for lang=$lang, categ=$categ, ft=$ft, testId=$testId, distName=$distName = $res{$testId}");
	}		
	$self->{logger}->logconfess("BUG: empty distances") if (scalar(keys %res)==0);
	return \%res;
}

1;
