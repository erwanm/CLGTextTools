package Text::TextAnalytics::PAN13::FeatSelect;


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use Data::Dumper;
use Text::TextAnalytics::Util qw/pickInList selectMFValueCriterion pickInListProbas/;

our $VERSION = $Text::TextAnalytics::VERSION;

my $paramWeightIfUnseen = 1; # not good


# init columns names
# recall that dist = dist vs. other categs = soemthing you want to maximize
#             sim = sim to others categs = something you want to mimnimze
my @distribSelecSim = qw/bhattaDiscCoeff  commonArea/;
my @distribSelecDist = qw/bhattaReg bhattaAlt bhattaDiscDist diffArea/;
my @meanTypes = qw/arithm geom harmo/;

my @lowestCols =  ("rangeMinMax", "rangeMinMaxRelMean", "rangeQ1Q3", "rangeQ1Q3RelMedian", "stdDev", "stdDevRelMean" ); 
my @greatestCols = ( "mean", "median", "min" );
foreach my $mean (@meanTypes) {
	foreach my $name (@distribSelecSim) {
		push(@lowestCols, $name."Distrib".$mean);
	} 	
	foreach my $name (@distribSelecDist) {
		push(@greatestCols, $name."Distrib".$mean);
	} 	
}
my %isLowestByColumnSelect;
foreach my $elem (@lowestCols) {
	$isLowestByColumnSelect{$elem} = 1;
}
foreach my $elem (@greatestCols) {
	$isLowestByColumnSelect{$elem} = 0;
}

my $defaultParams = {
	withFilter => [0,1],
	nbSelectSteps => [1,2],
	filter => { "shapiroNormal" => { "column" => ["shapiroPVal"], "absRel" => ["rel"], "greater" => [1], "strictly" => [1], "threshold" => [0.05] },
				"stdDevNonZero" => { "column" => ["stdDev"], "absRel" => ["rel"], "greater" => [1], "strictly" => [1], "threshold" => [0] },
				"numeric" => {
								"column" => [ "mean", "median", "min"],
#								"threshold" => [0,1,2,5,10],
								"threshold" => [0,0.00001,0.0001,0.001,0.01],
								"absRel" => ["rel"], 
								"greater" => [1], 
								"strictly" => [1]
				}
			  },
	selectNBest => {
				"lowestByColumn" => \%isLowestByColumnSelect,
				"absRel" => [ "rel" ],
				"size" => [ 5, 10, 20, 50, 100, 200, 500, 1000 ]
			  }
	
};



sub newRandom() {
	my ($class, $mfWeights, $categ, $ft, $distName) = @_;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	my $self;
#	foreach my $p (keys %$defaultParams) {
#		$params->{$p} = $defaultParams->{$p} unless (defined($params->{$p}));
#	}
	$self = generateRandomConfig($mfWeights,$categ,$ft, $distName, $logger );
	$self->{logger} = $logger;
	bless($self, $class);
	return $self;
}

sub newFromId {
	my $class = shift;
	my $items = shift;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__);
	my $self;
	$self->{logger} = $logger;
	$self->{nbSelectSteps} = scalar(@$items)-1;
	my $filterId=shift(@$items);
	if ($filterId eq "undef") {
		$self->{withFilter}=0;
	} else {
		$self->{withFilter}=1;
		$self->{filter} = filterFromId($filterId, $logger);
	}
	my @selectSteps = map { selectStepFromId($_, $logger) } @$items;
	$self->{selectNBest} = \@selectSteps; 
	bless($self, $class);
	return $self;
}

sub getSelectStepsColumns {
	my $self =shift;
	my @res = map {$_->{column} } @{$self->{selectNBest}};
	return \@res;
}

sub getFinalSize {
	my $self = shift;
	my $lastStep=scalar(@{$self->{selectNBest}})-1;
	return $self->{selectNBest}->[$lastStep]->{size};
}

sub getMetaFeatures {
	my $self = shift;
	my $categ = shift;
	my $ft = shift;
	my $distName = shift;
	my @res;
	
#	push(@res, [ "withFilter", $self->{withFilter} ]);
	push(@res, [ "distNameWithFilterPair", "$distName-".$self->{withFilter} ]);
	if ($self->{filter}) {
		push(@res, [ "filterDistNameFilterNamePair" , "$distName-".$self->{filter}->{name} ]);
		push(@res, [ "filterColThresholdPair" , $self->{filter}->{column}."-".$self->{filter}->{threshold} ]) ;
		push(@res, [ "filterDistNameColPair" , "$distName-".$self->{filter}->{column} ]);
	}
#	push(@res, [ "nbSelectStep", $self->{nbSelectSteps} ]);
	push(@res, [ "distNameNbSelectStep", "$distName-".$self->{nbSelectSteps} ]);
	foreach my $step (@{$self->{selectNBest}}) {
	    my $colType = substr($step->{column},0,6);
		push(@res, [ "selectCol", $step->{column} ]);
		push(@res, [ "distNameSelectColTypePair", $distName."-".$colType ]);
		push(@res, [ "featTypeSelectColTypePair", "$ft-".$colType ]);
#		push(@res, [ "selectColSize", $step->{column}."-".$step->{size} ]);
		push(@res, [ "distNameSelectSizePair", $distName."-".$step->{size} ]);
		push(@res, [ "featTypeSelectSizePair", "$ft-".$step->{size} ]);
	}  
	# TODO how to take these into account in a clean way?
#	my $lastStep=scalar(@{$self->{selectNBest}})-1;
#	my $finalSelectSize = $self->{selectNBest}->[$lastStep]->{size};
#	push(@res, [ "finalSelectSize", $finalSelectSize ]);
#	push(@res, [ "distNameFinalSelectSizePair", "$distName-$finalSelectSize" ]);
#	push(@res, [ "featTypeFinalSelectSizePair", "$ft-$finalSelectSize" ]);
#	if ($lastStep>0) {
#	    my $colType1 = substr($self->{selectNBest}->[0]->{column},0,6);
#	    my $colType2 = substr($self->{selectNBest}->[1]->{column},0,6);
#	    push(@res, ["selectPair", "$colType1-$colType2" ]);
#	}
	return \@res;
}


sub convertMetaFeaturesToParametersWeights {
	my $metaFeatures = shift;
	my $selectCriterion = shift;
	my $categories = shift;
	my $featuresTypes =  shift;
	my $distNames = shift;
	my $logger = shift;

	my $res;

	my @colTypes;
	$logger->debug("convert select meta-features to weights: selectCriterion=$selectCriterion  ");
	foreach my $col (keys %isLowestByColumnSelect) {
		my $colType = substr($col,0,6);
	    push(@colTypes, $colType);
		$res->{selectColNameByColType}->{$colType}->{$col} = selectMFValueCriterion($metaFeatures->{selectCol},  $col, $selectCriterion) || $paramWeightIfUnseen;
	}
	foreach my $distName (@$distNames) {
	    $logger->trace("distName=$distName");
		foreach my $withFilter (@{$defaultParams->{withFilter}}) {
			$res->{withFilterByDistName}->{$distName}->{$withFilter}  = selectMFValueCriterion($metaFeatures->{distNameWithFilterPair},  "$distName-$withFilter", $selectCriterion) || $paramWeightIfUnseen;
		}
		foreach my $nbSelectSteps (@{$defaultParams->{nbSelectSteps}}) {
			$res->{nbSelectStepsByDistName}->{$distName}->{$nbSelectSteps}  = selectMFValueCriterion($metaFeatures->{distNameNbSelectStep},  "$distName-$nbSelectSteps", $selectCriterion) || $paramWeightIfUnseen;
		}
		foreach my $filterName (keys %{$defaultParams->{filter}}) {
		    $logger->trace("filterName=$filterName");
			$res->{filterNameByDistName}->{$distName}->{$filterName}  = selectMFValueCriterion($metaFeatures->{filterDistNameFilterNamePair},  "$distName-$filterName", $selectCriterion) || $paramWeightIfUnseen;
			foreach my $filterCol (@{$defaultParams->{filter}->{$filterName}->{column}}) {
				$res->{filterColByDistAndFilterName}->{$distName}->{$filterName}->{$filterCol}  = selectMFValueCriterion($metaFeatures->{filterDistNameColPair},  "$distName-$filterCol", $selectCriterion) || $paramWeightIfUnseen;
					foreach my $filterThreshold (@{$defaultParams->{filter}->{$filterName}->{threshold}}) {
						$res->{filterThresholdByNameAndCol}->{$filterName}->{$filterCol}->{$filterThreshold}  = selectMFValueCriterion($metaFeatures->{filterColThresholdPair},  "$filterCol-$filterThreshold", $selectCriterion) || $paramWeightIfUnseen;
					}
			}
		}
		foreach my $ft (@$featuresTypes) {
			foreach my $colT (@colTypes) {
				my $valFT = selectMFValueCriterion($metaFeatures->{featTypeSelectColTypePair},  "$ft-$colT", $selectCriterion) || $paramWeightIfUnseen;
				my $valDist = selectMFValueCriterion($metaFeatures->{distNameSelectColTypePair},  "$distName-$colT", $selectCriterion) || $paramWeightIfUnseen;
				$res->{selectColTypeByFTAndDistName}->{$ft}->{$distName}->{$colT} = ($valFT + $valDist) / 2 ;
			}
			foreach my $size (@{$defaultParams->{selectNBest}->{size}}) {
				my $valFT = selectMFValueCriterion($metaFeatures->{featTypeSelectSizePair},  "$ft-$size", $selectCriterion) || $paramWeightIfUnseen;
				my $valDist = selectMFValueCriterion($metaFeatures->{distNameSelectSizePair},  "$distName-$size", $selectCriterion) || $paramWeightIfUnseen;
				$res->{selectSizeByFTAndDistName}->{$ft}->{$distName}->{$size} = ($valFT + $valDist) / 2 ;
			}
		}
	}
	return $res;
	
}



sub generateRandomConfig {
	my $mfWeights = shift;
	my $categ= shift;
	my $ft = shift;
	my $distName = shift;
	my $logger = shift;

	my %res;
	$logger->debug("random select config: categ=$categ ; ft=$ft ; distName=$distName ");
	$res{withFilter} = pickInListProbas($mfWeights->{withFilterByDistName}->{$distName});
	$res{filter} = undef;
	if ($res{withFilter}) {
	    my $filterName =  pickInListProbas($mfWeights->{filterNameByDistName}->{$distName});
	    $res{filter}->{name} = $filterName;
#		$logger->trace("DEBUG name=".$res{filter}->{name}." ; distName =  $distName ");
#		$logger->trace({filter => \&Dumper, value => $mfWeights->{filterColByDistAndFilterName}});
		$res{filter}->{column} = pickInListProbas($mfWeights->{filterColByDistAndFilterName}->{$distName}->{$res{filter}->{name}});
#		$logger->trace({filter => \&Dumper, value => $mfWeights->{filterThresholdByNameAndCol}->{$res{filter}->{name}}});
		$res{filter}->{threshold} = pickInListProbas($mfWeights->{filterThresholdByNameAndCol}->{$res{filter}->{name}}->{$res{filter}->{column}});
		foreach my $p (keys %{$defaultParams->{filter}->{$filterName}}) {
		    if (!defined($res{filter}->{$filterName}->{$p})) {
			$res{filter}->{$p} = pickInList($defaultParams->{filter}->{$filterName}->{$p});
		    }
		}
	}
	do { 
	    $res{selectNBest} = [];
	    $res{nbSelectSteps} = pickInListProbas($mfWeights->{nbSelectStepsByDistName}->{$distName});
	    my $step1 = generateRandomSelectStep($mfWeights,$categ,$ft, $distName );
	    while (!compatibleSelectWithFilter($step1, $res{filter})) {
			$step1 = generateRandomSelectStep($mfWeights,$categ,$ft, $distName );
	    }
	    my $stepIndex=0;
	    $res{selectNBest}->[$stepIndex] = $step1;
	    $stepIndex++;
	    while ($stepIndex<$res{nbSelectSteps}) {
			$res{selectNBest}->[$stepIndex] = generateRandomSelectStep($mfWeights,$categ,$ft, $distName );
			$stepIndex++;
	    }
	    $logger->trace("Trying with select random config below...");
	    $logger->trace({filter => \&Dumper, value => \%res});
	    
	} while (($res{nbSelectSteps}>1) && (!compatibleSelect2WithSelect1($res{selectNBest}->[1], $res{selectNBest}->[0]) || !compatibleSelectWithFilter($res{selectNBest}->[1], $res{filter}))); # not done for more than 2 steps
    $logger->trace("Random config accepted");

	return \%res;
}


sub generateRandomSelectStep {
	my $mfWeights = shift;
	my $categ= shift;
	my $ft = shift;
	my $distName = shift;
	
	my %res;
	# TODO absRel
	$res{absRel} = "rel"; 
	my $colType = pickInListProbas($mfWeights->{selectColTypeByFTAndDistName}->{$ft}->{$distName});
	$res{column} = pickInListProbas($mfWeights->{selectColNameByColType}->{$colType});
	$res{selectLowest} = $defaultParams->{selectNBest}->{lowestByColumn}->{$res{column}};
	$res{size} = pickInListProbas($mfWeights->{selectSizeByFTAndDistName}->{$ft}->{$distName});
	return \%res;
}


sub filterFromId {
	my $id = shift;
	my $logger = shift;
	my %filter;
	my @pieces = split("-", $id);
	my $strT;
	($filter{column}, $filter{absRel}, $filter{strictly}, $filter{greater}, $strT) = @pieces;
	$logger->logconfess("invalid format filter id $id") if (!defined($strT));
	$strT =~ s/o/./g;
	$filter{threshold}=	$strT;
	return \%filter;
}

sub selectStepFromId {
	my $id = shift;
	my $logger = shift;
	my @pieces = split("-", $id);
	my %res;
	($res{column}, $res{size}, $res{absRel}, $res{selectLowest}) = @pieces;
	$logger->logconfess("invalid format select  id $id") if (!defined($res{selectLowest}));
	return \%res;
}

sub getId {
	my $self = shift;
	return $self->getFilterId()."_".$self->getSelectId();
}


sub getFilterId {
	my $self = shift;
	my $res;
	if (defined($self->{filter})) {
		my $strThreshold = $self->{filter}->{threshold};
		$strThreshold =~ s/\./o/g;
		$res = $self->{filter}->{column}."-".$self->{filter}->{absRel}."-".$self->{filter}->{strictly}."-".$self->{filter}->{greater}."-".$strThreshold;
	} else {
		$res = "undef";
	}
	return $res;
}

sub getSelectId {
	my $self = shift;
	my @res;

	foreach my $step (@{$self->{selectNBest}}) {
	    push(@res, $self->getSelectStepId($step));
	}
	return join("_", @res);
}

sub getSelectStepId {
	my $self = shift;
	my $step = shift;
#	$self->{logger}->logconfess("BUG how can you arrive here with step undef???") if (!$step);
	return $step->{column}."-".$step->{size}."-".$step->{absRel}."-".$step->{selectLowest};
}


sub compatibleSelect2WithSelect1 {
	my ($step2, $step1) = @_;
	die "BUG" if (!defined($step2));
	return 0 if ($step1->{column} eq $step2->{column});
	return 0 if ($step2->{size} >= $step1->{size});
	return 1;
}

sub compatibleSelectWithFilter {
	my ($selectStep, $filter) = @_;
	return 1 if (!defined($filter));
	return 1 if ($filter->{name} ne "numeric");
	return 0 if ($filter->{column} eq $selectStep->{column});
	return 1;
}



sub readIndexesFile {
	my $self = shift;
	my $f = shift;
	my @res;
	open(FILE, "<", "$f") or $self->{logger}->logconfess("can not open $f");
	while (<FILE>) {
		chomp;
		push(@res,$_); 
	}
	close(FILE);
	return \@res;
}

sub writeIndexesFile {
	my $self = shift;
	my $indexes = shift;
	my $f = shift;
	open(FILE, ">", "$f") or $self->{logger}->logconfess("can not open $f for writing");
	foreach my $index (@$indexes) {
		print FILE "$index\n";
	}
	close(FILE);
}


# convention! $indexes is  undef means that there was no filter/selection at all (i.e. all indexes are actually valid) (different from empty list)
sub getIndexes {
	my $self = shift;
	my $boss = shift; 
	my $lang = shift;
	my $categ = shift;
	my $ft = shift;
	
	my $dir = $boss->{workDir}."/indexes/$lang/$categ/$ft";
	
	my $idStr = $self->getId();
	my $target = "$dir/$idStr.indexes";
	my @res;
	if (-f $target) {
		return $self->readIndexesFile($target);
	}
	my @id = split("_", $idStr);
	my $indexes;
	my $stage=0;
	if ((scalar(@id) == 3) && (-f "$dir/".$id[0].$id[1]."indexes")) {
		$indexes = $self->readIndexesFile("$dir/".$id[0].$id[1]."indexes");
		$stage=2;
	} 
	if (!$stage && $self->{filter} && (-f "$dir/".$id[0]."indexes")) {
		$indexes = $self->readIndexesFile("$dir/".$id[0]."indexes");
		$stage=1;
	}
	for (my $s=$stage; $s<scalar(@id); $s++) {
		if ($s == 0) {
			$indexes = $self->applyFilter($boss, $lang, $categ, $ft) if ($self->{filter});
		} else {
			$indexes = $self->applySelect($boss, $self->{selectNBest}->[$s-1], $indexes, $lang, $categ, $ft);
		}
	}
	$self->{logger}->debug("Select config ".$self->getId().": ".scalar(@$indexes)." indexes as result") if ($self->{logger}->is_debug());

	return $indexes;
}


sub applyFilter {
	my $self = shift;
	my $boss = shift;
	my $lang = shift; 
	my $categ = shift;
	my $ft = shift;
	my @res;
	
	my $data = $boss->{stats}->{$lang}->{$categ}->{$ft}->{$self->{filter}->{absRel}}->{$self->{filter}->{column}};
	$self->{logger}->logconfess("Data has not been loaded! was looking for boss->{stats}->{$lang}->{$categ}->{$ft}->{".$self->{filter}->{absRel}."}->{".$self->{filter}->{column}."}") unless (defined($data));
	$self->{logger}->trace("found data boss->{stats}->{$lang}->{$categ}->{$ft}->{".$self->{filter}->{absRel}."}->{".$self->{filter}->{column}."}");
	
	my $strict = $self->{filter}->{strictly};
	my $greater = $self->{filter}->{greater};
	my $threshold = $self->{filter}->{threshold};
	for (my $i=1; $i<scalar(@$data); $i++) {
		my $value = $data->[$i];
		if (($value ne "NA") && ($value !~ m/inf/) ) {
			my $keep;
			if ($greater) {
				$keep = ($strict) ? $value > $threshold : $value >= $threshold ;
			} else {
				$keep = ($strict) ? $value < $threshold : $value <= $threshold ;
			}
			push(@res,$i) if ($keep);
		}
	}
		
	$self->writeIndexesFile(\@res, $boss->{workDir}."/indexes/$lang/$categ/$ft/".$self->getFilterId());
	return \@res;
}



# remark : it is possible that a filter returns 0 values -> also return 0 values
#
sub applySelect {
	my $self = shift;
	my $boss = shift; 
	my $step = shift;
	my $indexes = shift;
	my $lang = shift;
	my $categ = shift;
	my $ft = shift;

	my $data = $boss->{stats}->{$lang}->{$categ}->{$ft}->{$step->{absRel}}->{$step->{column}};
	$self->{logger}->logconfess("Data has not been loaded! was looking for boss->{stats}->{$lang}->{$categ}->{$ft}->{".$step->{absRel}."}->{".$step->{column}."}") unless (defined($data));
	$self->{logger}->debug("Selection: data found from self->{stats}->{$lang}->{$categ}->{$ft}->{".$step->{absRel}."}->{".$step->{column}."}");
	
	if (!defined($indexes)) { # convention: undef means nothing happened before, all indexes are valid
		my @seq = (1 .. scalar(@$data)-1);
		$indexes = \@seq;
	}
	$self->{logger}->debug("Starting selection with lang=$lang, categ=$categ, ft=$ft, initial indexes size=".scalar(@$indexes));
	my $lowest = $step->{selectLowest};
	my $size = $step->{size};
	my @validIndexes; # mainly to eliminate any NA
	foreach my $i (@$indexes) {
		my $value = $data->[$i];
		if (($value ne "NA") && ($value ne "nan") && ($value !~ m/inf/)) { 
		    $self->{logger}->trace("Value at index $i=$value");
			push(@validIndexes,$i);
		} else {
		    $self->{logger}->trace("Discarding index $i=NA");
		}
	}
	$self->{logger}->debug("Indexes size after eliminating NA values =".scalar(@validIndexes));
	
	if (scalar(@validIndexes)<= $size) {
		$self->{logger}->debug("Not enough data for selecting $size best (only ".scalar(@validIndexes)." values) for $lang,$categ,$ft in ".$self->getId()) if (scalar(@validIndexes)< $size);
		return \@validIndexes;
	}

	my @sortedByValue;
#	eval {
#		 local $SIG{'__DIE__'};
	 @sortedByValue =  ($lowest) ? sort { $data->[$a] <=> $data->[$b] } @validIndexes :  sort { $data->[$b] <=> $data->[$a] } @validIndexes ;
#	};
#	if ($@) {
#		$self->{logger}->warn("The following error happened: $@");
#		$self->{logger}->info("Content of validIndexes: ");
#		$self->{logger}->info({ filter => \&Dumper, value => \@validIndexes });
#		$self->{logger}->info("Content of data: ");
#		$self->{logger}->info({ filter => \&Dumper, value => $data });
#		return [];
#	}
	
	my @res =  (sort  { $a <=> $b } @sortedByValue[0..$size-1]);

	$self->writeIndexesFile(\@res, $boss->{workDir}."/indexes/$lang/$categ/$ft/".$self->getSelectStepId($step));
	return \@res;
}


1;
