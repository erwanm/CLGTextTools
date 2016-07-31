package CLGTextTools::Stats;


#twdoc
#
# Library containing various statistics-related functions.
#
# ---
# Erwan Moreau 2015-2016
#
#/twdoc

use strict;
use warnings;
use Log::Log4perl;
use Carp;
use CLGTextTools::Logging qw/confessLog warnLog/;
use CLGTextTools::Commons qw/containsUndef/;

use base 'Exporter';
our @EXPORT_OK = qw/sum min max mean median stdDev geomMean harmoMean means aggregateVector pickIndex pickInList pickInListProbas pickNSloppy  pickNIndexesAmongMSloppy pickNIndexesAmongMExactly  pickDocSubset splitDocRandom splitDocRandomAvoidEmpty averageByGroup scaleDoc scaleUpMaxDocSize getDocsSizes getDocSize normalizeFreqDoc/;





#twdoc sum(@$values, $naStr)
#
# returns the sum of the values, ignoring undefined values, and returns 0 if no values at all.
# $naStr is used instead of undef if it is defined. If not, perl will complain about undef values.
#
#/twdoc
sub sum {
    my $values = shift;
    my $naStr = shift;
    my $res=0;
    foreach my $v (@$values) {
	if (!defined($naStr) || ($v ne $naStr)) {
	    $res += $v;
	}
    }
    return $res;
}


#twdoc min(@$values, $naStr)
#
# returns the minimum value of the vector, ignoring undef values.
# $naStr is used instead of undef if it is defined.
#
#/twdoc
sub min {
    my $values = shift;
    my $naStr = shift;
    my $min=undef;
    foreach my $v (@$values) {
	if ( defined($v) && ( !defined($naStr) || ($v ne $naStr) ) ) {
	    $min = $v if (!defined($min) || ($v>$min));
	}
    }
    return (defined($min)) ? $min : ( defined($naStr) ? $naStr : undef );
}



#twdoc max(@$values, $naStr)
#
# returns the maximum value of the vector, ignoring undef values.
# $naStr is used instead of undef if it is defined.
#
#/twdoc
sub max {
    my $values = shift;
    my $naStr = shift;
    my $max=undef;
    foreach my $v (@$values) {
	if ( defined($v) && ( !defined($naStr) || ($v ne $naStr) ) ) {
	    $max = $v if (!defined($max) || ($v>$max));
	}
    }
    return (defined($max)) ? $max : ( defined($naStr) ? $naStr : undef );
}


#twdoc mean(@$values, $naStr)
#
# returns the arithmetic mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
#
#/twdoc
sub mean {
    my $values = shift;
    my $naStr = shift;
    my $sum=0;
    my $n=0;
    foreach my $v (@$values) {
	if (defined($v) && (!defined($naStr) || ($v ne $naStr))) {
	    $sum += $v;
	    $n++;
	}
    }
    return ($n>0) ? $sum / $n : ( defined($naStr) ? $naStr : undef );
}


#twdoc  median(@$values, $naStr)
# 
# returns the median of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# 
#/twdoc
sub median {
    my $values = shift;
    my $naStr = shift;

    my @sorted = sort { $a <=> $b } grep { !defined($naStr) || ($_ ne $naStr) } @$values;
    return ( defined($naStr) ? $naStr : undef ) if (scalar(@$values) == 0);
    if (scalar(@sorted) % 2 == 0) { # even
	my $n = scalar(@sorted) / 2;
	my ($v1, $v2)  = ($sorted[$n-1],$sorted[$n]);
	if ((defined($v1) && (!defined($naStr) || ($v1 ne $naStr))) && (defined($v2) && (!defined($naStr) || ($v2 ne $naStr)))) {
	    return ($v1 + $v2) / 2;
	} else {
	    return ( defined($naStr) ? $naStr : undef );
	}
    } else { # odd
	my $n = int(scalar(@sorted) / 2);
	return $sorted[$n];
    }
}


#twdoc stdDev(@$values, $naStr)
# 
# returns the std dev of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# 
#/twdoc
sub stdDev {
    my $values = shift;
    my $naStr = shift;
    my $sum=0;
    my $sqSum=0;
    my $n=0;
    foreach my $v (@$values) {
	if (defined($v) && (!defined($naStr) || ($v ne $naStr))) {
	    $sum += $v;
	    $sqSum += $v**2;
	    $n++;
	}
    }
    if ($n>0) {
	my $var = ( $sqSum - ($sum**2 / $n) ) / $n ;
	$var = 0 if ($var < 0); # floating precision error possible if std dev = 0
	return sqrt($var);
    } else {
	return defined($naStr) ? $naStr : undef ;
    }
}


#twdoc geomMean(@$values, $naStr)
# 
# returns the geometric mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# 
#/twdoc
sub geomMean {
    my $values = shift;
    my $naStr = shift;
    my $prod=1;
    my $n=0;
    foreach my $v (@$values) {
	if (defined($v) && (!defined($naStr) || ($v ne $naStr))) {
	    $prod *= $v;
	    $n++;
	}
    }
    my $res  = ($n>0) ? $prod**(1/$n) : ( defined($naStr) ? $naStr : undef );
    # problem: for some reason, NaN is still returned by perl in some cases
    $res = $naStr if (($res eq "nan") && defined($naStr));
#    print STDERR "DEBUG geomMean: n=$n, prod=$prod, res=$res\n";
    return $res;
}


#twdoc harmoMean(@$values, $naStr)
# 
# returns the harmonic mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# Zero values are not ignored: if there is a zero value, the result is undef (or $naStr)
# 
#/twdoc
sub harmoMean {
    my $values = shift;
    my $naStr = shift;
    my $sum=0;
    my $n=0;
    foreach my $v (@$values) {
	if (defined($v) && (!defined($naStr) || ($v ne $naStr))) {
	    if ($v == 0) {
		return  defined($naStr) ? $naStr : undef  ;
	    } else {
		$sum += 1/$v;
		$n++;
	    }
	}
    }
    return ($n>0) ? $n/$sum : ( defined($naStr) ? $naStr : undef );
}

#twdoc  means(@$values, $naStr)
# 
# returns the arithmetic, geometric and harmonic mean of the values (following the exceptions defined form each function) in a hash.
# $naStr is used instead of undef if it is defined.
# 
#/twdoc
sub means {
    my $values = shift;
    my $naStr = shift;
    my $res = { "arithm" => mean($values, $naStr) ,  "geom" => geomMean($values, $naStr) , "harmo" => harmoMean($values, $naStr) };
#    print STDERR "DEBUG MEANS values = ".join(" ; ", @$values)."... results = ".join(" ; ", (values %$res))."\n";
    return $res;
}


#twdoc aggregateVector(@$values, $aggregType, $naStr)
# 
# returns the value corresponding to the statistic described by $aggregType: 'median', 'arithm', 'geom', 'harmo' for the array ref @$values.
# $naStr is used instead of undef if it is defined.
# 
#/twdoc
sub aggregateVector {
    my $values = shift;
    my $aggregType = shift;
    my $naStr = shift;
    
    if ($aggregType eq "median") {
	return median($values, $naStr);
    } elsif ($aggregType eq "arithm") {
	return mean($values, $naStr);
    } elsif ($aggregType eq "geom") {
	return geomMean($values, $naStr);
    } elsif ($aggregType eq "harmo") {
	return harmoMean($values, $naStr);
    } else {
	die "Error: invalid value '$aggregType' as 'aggregType' in aggregateVector";
    }
 
}



#twdoc pickInList(@$list)
#
# picks randomly a value in a list.
# Uniform probability distribution over cells (thus a value occuring twice is twice more likely to get picked than a value occuring only once).
# Fatal error if the array is empty.
#
#/twdoc
sub pickInList {
    my $list = shift;
#print Dumper($list);
    confess "Wrong parameter: not an array or empty array" if ((ref($list) ne "ARRAY") || (scalar(@$list)==0));
    return $list->[int(rand(scalar(@$list)))];
}



#twdoc pickIndex(@$list)
#
# picks an index randomly in a list, i.e. simply returns an integer between 0 and n-1, where n is the size of the input list.
# 
#/twdoc
#
sub pickIndex {
    my $list = shift;

    confess "Wrong parameter: not an array or empty array" if ((ref($list) ne "ARRAY") || (scalar(@$list)==0));
    my $n = scalar(@$list);
    return int(rand(scalar(@$list)));
}


#twdoc pickInListProbas(%$hash)
#
# picks a random value among (keys %$hash) following, giving each key a probability proportional to $hash->{key} w.r.t to all values in (values %$hash)
# Remark: method is equivalent to scaling the sum of the values (values %$hash) to 1, as if these represented a stochastic vector of probabilities.
# Fatal error if the array is empty.
#
#/twdoc
sub pickInListProbas {
    my $areaByValue = shift;
    confess "Wrong parameter: not a hash or empty hash" if ((ref($areaByValue) ne "HASH") || (scalar(keys %$areaByValue)==0));
    my $areaTotal = 0;
    while (my ($item, $area) = each %$areaByValue) {
	$areaTotal += $area;
#    print STDERR "DEBUG $item : $area (total = $areaTotal)\n";
    }
    my $rndProba = rand($areaTotal);
    $areaTotal = 0;
    while (my ($item, $area) = each %$areaByValue) {
	$areaTotal += $area;
#    print STDERR "DEBUG $item : $area (total = $areaTotal, random = $rndProba)\n";
	return $item if ($rndProba < $areaTotal); 
    }
    die "BUG should never have arrived here";
}


#twdoc pickNSloppy($n, $list)
#
# randomly picks ``$n`` (unique) elements from the list, but not exactly. 
# In fact, the method returns a list of "statistical size" ``$n``: every element in the list
# has a chance ``$n / size($list)`` to be picked.
# Remark: if ``$n>=size(list)``, returns all elements from the list.
#
#/twdoc
sub pickNSloppy {
    my $n= shift;
    my $list = shift;
    my @res;
    my $proba = $n / scalar(@$list);
    foreach my $e (@$list) {
	push(@res, $e) if (rand() <= $proba);
    }
    return \@res;
}


#twdoc pickNIndexesAmongMSloppy($n, $m)
#
# randomly picks ``$n`` (unique) indexes from the list of indexes ``[0,..,$m-1]``, but not exactly. 
# In fact, the method returns a list of "statistical size" ``$n``: every element in the list
# has a chance ``$n / $m`` to be picked.
# Remark: if ``$n>=$m``, returns all elements from the list.
#
#/twdoc
sub pickNIndexesAmongMSloppy {
    my $n = shift;
    my $m = shift;
    my $proba = $n / $m;
    my @res;
    for (my $i=0;$i<$m; $i++) {
	push(@res, $i) if (rand() <= $proba);
    }
    return \@res;
}



#twdoc pickNIndexesAmongMExactly($n, $m)
#
# randomly picks ``$n`` (unique) indexes from the list of indexes ``[0,..,$m-1]``. This function can be significantly slower than ``pickNIndexesAmongMSloppy``.
#
# * An error is raised if ``$n>$m``.
#
#/twdoc
sub pickNIndexesAmongMExactly {
    my ($n, $m) = @_;

    confess "Error: cannot pick $n indexes among $m without replacement" if ($n>$m);
    my %h = map { $_ => 1 } (1..$m);
    my @res;
    while ($n>0) {
	my @keys = keys(%h);
	my $i = int(rand(scalar(@keys)));
	push(@res, $i);
	delete $h{$i};
	$n--;
    }
    return \@res;
}



#twdoc pickDocSubset($doc, $propObsSubset, ?$logger)
#
# given a document as a hash ``$doc->{obs} = freq`` (one obs type only), returns a random subset of size ``$prop * size($doc)`` (non exact size).
#
# * the random extraction is by occurrence, not simply by observation.
# * can be used to pick random subsets with replacements.
#
#/twdoc
sub pickDocSubset {
    my ($doc, $propObsSubset, $logger) = @_;
    my %subset;
    $logger->debug("Picking doc subset, prop = $propObsSubset") if ($logger);
    my ($obs, $nb);
    while (($obs, $nb) = each %$doc) {
        for (my $i=0; $i< int($nb + 0.5); $i++) {
            $subset{$obs}++ if (rand() < $propObsSubset);
        }
	$logger->trace("obs = '$obs'; nb = $nb ; selected = ".(defined($subset{$obs})?$subset{$obs}:0)) if ($logger);
    }
    return \%subset;
}


#twdoc splitDocRandom($doc, $nbBins, ?probas, ?$logger)
#
# given a document as a hash ``$doc->{obs} = freq`` (one obs type only), splits the observations into ``$nbBins`` subsets of size  ``size($doc)/$nbBins``.
# The output is a list ref of size ``$nbBins``.
#
# * ``$probas`` is an optional hash ref ``$probas{index} = proba``: if supplied, every bin is picked according to the distribtuion described as values of the array. Its size must be equal to ``$nbBins``. If undefined, a uniform distribution is assumed.
#
# Warning: if the input document is small, it is possible that one of the bins is empty. In that case the corresponding subset is undef.
#
# * the random extraction is by occurrence, not simply by observation.
# * can be used to pick random subsets without replacements.
#
#/twdoc
sub splitDocRandom {
    my ($doc, $nbBins, $probas, $logger) = @_;
    my @subsets = (undef) x $nbBins;
    my ($obs, $nb);
    while (($obs, $nb) = each %$doc) {
        for (my $i=0; $i< int($nb + 0.5); $i++) {
	    my $bin = (defined($probas) ? pickInListProbas($probas) : int(rand($nbBins)) );
	    $logger->trace("obs = $obs, i=$i: bin = $bin") if ($logger);
	    $subsets[$bin]->{$obs}++;
        }
    }
    return \@subsets;
}


#twdoc splitDocRandomAvoidEmpty($nbAttempts, $doc, $nbBins, ?$probas, ?$logger)
#
# Calls ``splitDocRandom`` until every returned subset is non-empty, unless impossible within ``$nbAttempts`` attempts;
#
# * ``$probas`` is an optional hash ref ``$probas{index} = proba``: if supplied, every bin is picked according to the distribtuion described as values of the array. Its size must be equal to ``$nbBins``. If undefined, a uniform distribution is assumed.
#
#/twdoc
sub splitDocRandomAvoidEmpty {
    my ($nbAttempts, $doc, $nbBins, $probas, $logger) = @_;

    $logger->debug("splitting doc randomly: nb obs=".scalar(%$doc)."; nbAttempts=$nbAttempts; nbBins=$nbBins") if ($logger);
    my $res;
    while (containsUndef($res) && ($nbAttempts>0)) {
	$logger->trace("$nbAttempts attempts left") if ($logger);
	$res = splitDocRandom($doc, $nbBins, $probas, $logger);
	$nbAttempts--;
    }
#    return undef if (containsUndef($res));
    return $res;
}



#twdoc averageByGroup($table, $params, $logger)
#
#  groups together series of data which have the same values in certain columns, 
#  and calculates the average of a given other column for each such group. 
#
# Caution: columns (and rows) are indexed from 0.
#
# * ``$table`` is a two dimensions array: ``values->[rowNo]->[colNo] = value``
# * ``$logger``: optional
# * ``$params`` is a hash which optionally defines:
# ** valueArgNo: arg no for the value to use for the average. If undefined, 
#    then the last arg is used (this is the default). 
# ** groupByArgsNos: the args nos by which series of data should be   
#    grouped, separated by commas. For example if groupByArgsNos="2,4" then   
#    all lines with identical values in columns 2 and 4 are grouped together, 
#    and the result for each group is ``<val arg2> <val arg4> <average value>``.  
#    If the option is defined but is the empty string, then the group consists
#    in the whole data and the global average is the only output.
#    Default value (if undefined): 0 (first column only).  
# ** checkSameNumberByGroup: if true (default), a warning is emitted  
#    if there is not the same number of elements in every group.  
# ** expectedNumberByGroup: check that  there is the same number and this precise
#     number in every group (implies checkSameNumberByGroup)
#
#/twdoc
sub averageByGroup {
    my ($table, $params, $logger) = @_;

    confessLog($logger, "Error: empty table of values") if (scalar(@$table) == 0);
    my $nbCols = scalar(@{$table->[0]});
    my @groupsNos = defined($params->{groupByArgsNos}) ? split(/,/, $params->{groupByArgsNos}) : (0);
    my $valueArgNo = defined($params->{valueArgNo}) ? $params->{valueArgNo} : $nbCols-1;

    my %sumByGroup;
    my %nbByGroup;
    for (my $rowNo=0; $rowNo < scalar(@$table); $rowNo++) {
	my @groupValues = map { $table->[$rowNo]->[$_] } @groupsNos;
	my $groupId = join("\t", @groupValues);
	$sumByGroup{$groupId} += $table->[$rowNo]->[$valueArgNo];
	$nbByGroup{$groupId}++;
    }
    my $nbExpectedByGroup = undef;
    if (defined($params->{expectedNumberByGroup})) {
	$params->{checkSameNumberByGroup} = 1;
	$nbExpectedByGroup = $params->{expectedNumberByGroup};
    }
    foreach my $groupId (sort keys %sumByGroup) {
	if ($params->{checkSameNumberByGroup}) {
	    if (defined($nbExpectedByGroup)) {
		confessLog($logger, "Error: found $nbByGroup{$groupId} rows for group '$groupId', expected $nbExpectedByGroup.") if ($nbByGroup{$groupId} != $nbExpectedByGroup);
	    } else { # first group as ref
		$nbExpectedByGroup = $nbByGroup{$groupId};
	    }
	}
	my $avg = $sumByGroup{$groupId} / $nbByGroup{$groupId};
	print "$groupId\t$avg\n";
    }

}


#
#twdoc scaleDoc($doc, $newSize, ?$oldSize, ?$logger, ?$noWarning)
#
# given a document as a hash ``$doc->{obs} = freq`` (one obs type only), scales it up or down by multiplying every frequency by ``$newSize / $oldSize``
#
# remark: the random extraction is by occurrence, not simply by observation.
#
# * ``$oldSize`` is optional: if not provided the current size is calculated first (saves time if provided)
# * ``$logger`` optional
# * ``$noWarning`` optional: by default a warning is raised if the doc is empty (``$oldSize`` is zero)
#
#/twdoc
sub scaleDoc {
    my ($doc, $newSize, $oldSize, $logger, $noWarning) = @_;

    if (!defined($oldSize)) {
	$oldSize = 0;
	my ($obs, $nb);
	while (($obs, $nb) = each %$doc) {
	    $oldSize += $nb;
	}
    }
    if ($oldSize == 0) {
	warnLog($logger, "warning: empty document in scaleDoc") unless ($noWarning);
	return $doc;
    } else {
	my $coeff = $newSize / $oldSize ;

	my %res;
	my ($obs, $nb);
	while (($obs, $nb) = each %$doc) {
	    $res{$obs} = $nb * $coeff;
	}
	return \%res;
    }
}


#
#twdoc scaleUpMaxDocSize($docsList, ?$sizesList, ?$logger)
#
# Given a list of documents as hash ``$docsList->[i]->{obs} = freq`` (one obs type only), scales all of them to the size of the largest doc.
#
# remark: the random extraction is by occurrence, not simply by observation.
# 
# * ``$sizesList`` optional: list of the sizes (saves time if supplied)
# * ``$logger``
# * ``$noWarning`` optional: by default a warning is raised if a doc is empty (its size is zero)
#
#/twdoc
sub scaleUpMaxDocSize {
    my ($docsList, $sizesList, $logger, $noWarning) = @_;

    $sizesList = getDocsSizes($docsList) if (!defined($sizesList));
#    print STDERR "DEBUG sizesList = [".join(";", @$sizesList)."]\n";
    my $newSize = max($sizesList);

    my @res;
    for (my $i=0; $i<scalar(@$docsList); $i++) {
	if ($sizesList->[$i] <= $newSize) { # avoid the max doc
	    $res[$i] = scaleDoc($docsList->[$i], $newSize, $sizesList->[$i], $logger, $noWarning);
	} else {
	    $res[$i] = $docsList->[$i] ;
	}
    }
    
    return \@res;
}


#
#twdoc getDocsSizes($docsList, ?$logger)
#
# Given a list of documents as hash ``$docsList->[i]->{obs} = freq`` (one obs type only), returns  a list of their sizes in the same order.
#
#/twdoc
sub getDocsSizes {
    my ($docsList, $logger) = @_;

    my @sizes;
    for (my $i=0; $i<scalar(@$docsList); $i++) {
	my $doc = $docsList->[$i];
	my ($obs, $nb);
	while (($obs, $nb) = each %$doc) {
	    $sizes[$i] += $nb;
	}
	$sizes[$i] = 0 if (!defined($sizes[$i]));
    }
    return \@sizes;
}


#
#twdoc getDocsSize($doc, ?$logger)
#
# given a document as a hash ``$doc->{obs} = freq`` (one obs type only),  returns its size.
#
#/twdoc
sub getDocSize {
    my ($doc, $logger) = @_;

    my $size = 0;
    my ($obs, $nb);
    while (($obs, $nb) = each %$doc) {
	$size += $nb;
    }
    return $size;
}


#twdoc normalizeFreqDoc($doc, $total, ?$logger)
#
# given a document as a hash ``$doc->{obs} = freq`` (one obs type only),  normalizes the frequencies by dividing all of them by ``$total``.
#
#/twdoc
sub normalizeFreqDoc {
    my ($doc, $total, $logger) = @_;

    my %res;
    my ($obs, $nb);
    while (($obs, $nb) = each %$doc) {
	$res{$obs} = $nb / $total;
    }
    return \%res;


}


1;
