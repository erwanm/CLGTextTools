package CLGTextTools::Stats;

use strict;
use warnings;
use Log::Log4perl;
use Carp;
use CLGTextTools::Logging qw/confessLog/;

use base 'Exporter';
our @EXPORT_OK = qw/sum min max mean median stdDev geomMean HarmoMean means aggregateVector pickInList pickInListProbas pickNSloppy  pickNIndexesAmongMSloppy pickNIndexesAmongMExactly  pickDocSubset splitDocRandom splitDocRandomAvoidEmpty/;





# sum(@$values, $naStr)
#
# returns the sum of the values, ignoring undefined values, and returns 0 if no values at all.
# $naStr is used instead of undef if it is defined. If not, perl will complain about undef values.
#
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


# min(@$values, $naStr)
# returns the minimum value of the vector, ignoring undef values.
# $naStr is used instead of undef if it is defined.
#
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


# max(@$values, $naStr)
# returns the maximum value of the vector, ignoring undef values.
# $naStr is used instead of undef if it is defined.
#
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


# mean(@$values, $naStr)
#
# returns the arithmetic mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
#
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


#  median(@$values, $naStr)
# 
# returns the median of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# 
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


# stdDev(@$values, $naStr)
# 
# returns the std dev of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# 
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


# geomMean(@$values, $naStr)
# 
# returns the geometric mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# 
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


# geomMean(@$values, $naStr)
# 
# returns the harmonic mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
# $naStr is used instead of undef if it is defined.
# Zero values are not ignored: if there is a zero value, the result is undef (or $naStr)
# 
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

#  means(@$values, $naStr)
# 
# returns the arithmetic, geometric and harmonic mean of the values (following the exceptions defined form each function) in a hash.
# $naStr is used instead of undef if it is defined.
# 
sub means {
    my $values = shift;
    my $naStr = shift;
    my $res = { "arithm" => mean($values, $naStr) ,  "geom" => geomMean($values, $naStr) , "harmo" => harmoMean($values, $naStr) };
#    print STDERR "DEBUG MEANS values = ".join(" ; ", @$values)."... results = ".join(" ; ", (values %$res))."\n";
    return $res;
}


# aggregateVector(@$values, $aggregType, $naStr)
# 
# returns the value corresponding to the statistic described by $aggregType: 'median', 'arithm', 'geom', 'harmo' for the array ref @$values.
# $naStr is used instead of undef if it is defined.
# 
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



# pickInList(@$list)
#
# picks randomly a value in a list.
# Uniform probability distribution over cells (thus a value occuring twice is twice more likely to get picked than a value occuring only once).
# Fatal error if the array is empty.
#
sub pickInList {
    my $list = shift;
#print Dumper($list);
    confess "Wrong parameter: not an array or empty array" if ((ref($list) ne "ARRAY") || (scalar(@$list)==0));
    return $list->[int(rand(scalar(@$list)))];
}


# pickInListProbas(%$hash)
#
# picks a random value among (keys %$hash) following, giving each key a probability proportional to $hash->{key} w.r.t to all values in (values %$hash)
# Remark: method is equivalent to scaling the sum of the values (values %$hash) to 1, as if these represented a stochastic vector of probabilities.
# Fatal error if the array is empty.
#
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


# pickNSloppy($n, $list)
#
# randomly picks N elements from the list, but not exactly. 
# In fact, the method returns a list of "statistical size $n": every element in the list
# has a chance $n / size($list) to be picked.
# Remark: if $n>=size(list), returns all elements from the list.
#
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



# pickDocSubset(doc, prop)
#
# given a document as a hash: doc->{obs} = freq (one obs type only), returns a random subset of size prop * size(doc) (non exact size).
# remark: the random extraction is by occurrence, not simply by observation.
# remark: can be used to pick random subsets with replacements.
#
sub pickDocSubset {
    my ($doc, $propObsSubset) = @_;
    my %subset;
    my ($obs, $nb);
    while (($obs, $nb) = each %$doc) {
        for (my $i=0; $i< $nb; $i++) {
            $subset{$obs}++ if (rand() < $propObsSubset);
        }
    }
    return \%subset;
}


# splitDocRandom(doc, nbBins, ?probas)
#
# given a document as a hash: doc->{obs} = freq (one obs type only), splits the observations into nbBins subsets of size  size(doc)/nbBins.
# The output is a list ref of size nbBins.
# * probas is an optional parameter (hash ref index->proba): if supplied, every bin is picked according to the distribtuion described as values of the array. Its size must be equal to nbBins.
#
# Warning: if the input document is small, it is possible that one of the bins is empty. In that case the corresponding subset is undef.
#
# remark: the random extraction is by occurrence, not simply by observation.
# remark: can be used to pick random subsets without replacements.
#
sub splitDocRandom {
    my ($doc, $nbBins, $probas) = @_;
    my @subsets;
    my ($obs, $nb);
    while (($obs, $nb) = each %$doc) {
        for (my $i=0; $i< $nb; $i++) {
	    my $bin = (defined($probas) ? pickInListProbas($probas) : int(rand($nbBins)) );
	    $subsets[$bin]->{$obs}++;
        }
    }
    return \@subsets;
}



#
# Calls splitDocRandom until every returned subset is non-empty, unless impossible within $nbAttempts attempts.
#
#
sub splitDocRandomAvoidEmpty {
    my ($nbAttempts, $doc, $nbBins, $probas) = @_;

    my $res;
    while (containsUndef($res) && ($nbAttempts>0)) {
	$res = splitDocRandom($doc, $nbBins, $probas);
	$nbAttempts--;
    }
    return $res;
}


1;
