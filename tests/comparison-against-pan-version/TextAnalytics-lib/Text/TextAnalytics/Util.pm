package Text::TextAnalytics::Util;

use strict;
use warnings;
use Carp;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw/@possibleLogLevels rankWithTies initLog readFileToHash readConfigFile readTSVWithHeaderAsColumnsHash means aggregateVector mean median geomMean harmoMean readFileAsTokensList pickInList pickInListProbas pickNAmongSloppy pickNIndexesAmongMSloppy readTSVByColumnsNoHeader max discretize selectMFValueCriterion writeFileLineByLine sum stdDev/;

our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::Util - various useful subroutines

=cut

our @possibleLogLevels = qw/TRACE DEBUG INFO WARN ERROR FATAL OFF/;
our $encoding               = "utf-8";
our $defaultColumnSeparator = "\t";

=head1 DESCRIPTION

=head2 rankWithTies($parameters)

Computes a ranking which takes ties into account, i.e. two identical values are assigned the same rank.
The sum property is also fulfilled, i.e. the sum of all ranks is always 1+2+...+N (if first rank is 1). This implies
that the rank assigned to several identical values is the average of the ranks they would have been assigned if ties were not taken into account.

$parameters is a hash which must define:

=over 2

=item * values: a hash ref of the form $values->{id} = value. Can contain NaN values, but these values will be ignored.

=back

and optionally defines:

=over 2

=item * array: if defined, an array ref which contains the ids used as keys in values

=item * arrayAlreadySorted: (only if array is defined, see above). if set to true, "array" B<must be already sorted>. 
the sorting step will not be done (this way it is possible to use any kind of sorting) (the ranking step - with ties - is still done of course) 

=item * highestValueFirst: false by default. set to true in order to rank from highest to lowest values. Useless if array is defined. 

=item * printToFileHandle: if defined, a file handle where ranks will be printed.

=item * dontPrintValue: if defined and if printToFileHandle is defined, then lines are of the form
"<id> [otherData] <rank>"  instead of "<id> [otherData] <value> <rank>".
 
=item * otherData: hash ref of the form $otherData->{$id}=data. 
if defined and if printToFileHandle is defined, then lines like "<id> <otherData> [value] <rank>" will be written to the file instead of "<id> [value] <rank>".
if the "data" contains several columns, these columns must be already separated together but should not contain a column separator at the beginning or at the end.  

=item * columnSeparator: if defined and if printToFileHandle is defined, will be used as column separator (tabulation by default). 

=item * noNaNWarning: 0 by default, which means that a warning is issued if NaN values are found.
This does not happen if this parameter is set to true. not used if $array is defined.

=item * dontStoreRanking: By default the returned value is a hash ref of the form $ranking->{id}=rank containing the whole ranking. 
If dontStoreRanking is true then nothing is returned. 

=item * firstRank: rank starting value (1 by default).

=item * addNaNValuesBefore: boolean, default 0. by default NaN values are discarded. If true, these values are prepended to the ranking (before first real value).

=item * addNaNValuesAfter: boolean, default 0. by default NaN values are discarded. If true, these values are appended to the ranking (after last real value).

=back

=cut

sub rankWithTies {

	my ($parameters, $useLogger) = @_;
	my $firstRank =
	  defined( $parameters->{firstRank} ) ? $parameters->{firstRank} : 1;
	my $colSep =
	  defined( $parameters->{columnSeparator} )
	  ? $parameters->{columnSeparator}
	  : $defaultColumnSeparator;
	my $logger = Log::Log4perl->get_logger(__PACKAGE__) if ($useLogger);
	my $values = $parameters->{values};
	if ( !defined($values) ) {
	    if ($useLogger) {
		$logger->logconfess("Error: \$parameters->{values} must be defined.");
	    } else {
		die "Error: \$parameters->{values} must be defined.";
	    }
	}
	  
	my $array = $parameters->{array};
	if ( !defined($array) || !$parameters->{arrayAlreadySorted} ) {
		my @sortedIds;
		if ( $parameters->{highestValueFirst} ) {
			$logger->debug("Sorting by descending order (highest value first)") if ($useLogger);
			@sortedIds =
			  sort { $values->{$b} <=> $values->{$a} }
			  grep { $values->{$_} == $values->{$_} }
			  defined($array)
			  ? @$array
			  : keys %$values
			  ; # tricky: remove the NaN values before sorting. found in perl man page for sort.
		}
		else {
			$logger->debug("Sorting by ascending order (lowest value first)") if ($useLogger);
			@sortedIds =
			  sort { $values->{$a} <=> $values->{$b} }
			  grep { $values->{$_} == $values->{$_} }
			  defined($array)
			  ? @$array
			  : keys %$values
			  ; # tricky: remove the NaN values before sorting. found in perl man page for sort.
		}
		if (   $parameters->{addNaNValuesBefore}
			|| $parameters->{addNaNValuesAfter} )
		{
			my @NaNIds =
			  grep { $values->{$_} != $values->{$_} }
			  defined($array) ? @$array : keys %$values;
			my $nbValues    = scalar( keys %$values );
			my $nbNaNValues = scalar(@NaNIds);
			if ( scalar($nbNaNValues) > 0 ) {
				if ( $parameters->{addNaNValuesBefore} ) {
					unshift( @sortedIds, @NaNIds );
					if ( !$parameters->{noNaNWarning} ) {
					    if ($useLogger) {
						$logger->logwarn("$nbNaNValues NaN values (among $nbValues) prepended to ranking.") ;
					    } else {
						warn("$nbNaNValues NaN values (among $nbValues) prepended to ranking.") ;
					    }
					}
				}
				else {
					push( @sortedIds, @NaNIds );
					if ( !$parameters->{noNaNWarning} ) {
					    if ($useLogger) {
						$logger->logwarn(
						    "$nbNaNValues NaN values (among $nbValues) appended to ranking."
						    ) ;
					    } else {
						warn "$nbNaNValues NaN values (among $nbValues) appended to ranking.";
					    }
					}
				}
			}
		}
		elsif ( !$parameters->{noNaNWarning} ) {
			my $nbValues    = scalar( keys %$values );
			my $nbNaNValues = $nbValues - scalar(@sortedIds);
			if ( $nbNaNValues > 0 ) {
			    if ($useLogger) {
				$logger->logwarn("$nbNaNValues NaN values (among $nbValues) discarded from ranking." );
			    } else {
				warn "$nbNaNValues NaN values (among $nbValues) discarded from ranking.";
			    }
			}
		}
		$array = \@sortedIds;
	}
	my %ranks;
	my $i       = 0;
	my $fh      = $parameters->{printToFileHandle};
	my $ranking = undef;
	while ( $i < scalar(@$array) ) {
		my $currentFirst = $i;
		my $nbTies       = 0;
		while (( $i + 1 < scalar(@$array) )
			&& ( $values->{ $array->[$i] } == $values->{ $array->[ $i + 1 ] } )
		  )
		{
			$nbTies++;
			$i++;
		}
		my $rank = ( ( 2 * ( $currentFirst + $firstRank ) ) + $nbTies ) / 2;
		for ( my $j = $currentFirst ; $j <= $currentFirst + $nbTies ; $j++ ) {
			$ranks{ $array->[$j] } = $rank;
			if ( defined($fh) ) {
				my $otherData =
				  defined( $parameters->{otherData} )
				  ? $colSep . $parameters->{otherData}->{ $array->[$j] }
				  : "";
				my $valueData =
				  $parameters->{dontPrintValue}
				  ? ""
				  : $colSep . $values->{ $array->[$j] };
				print $fh $array->[$j]
				  . $otherData
				  . $valueData
				  . $colSep
				  . $rank . "\n";
			}
			if ( !$parameters->{dontStoreRanking} ) {
				$ranking->{ $array->[$j] } = $rank;
			}
		}
		$logger->debug(
"found $nbTies ties starting at position $currentFirst+1, assigned rank is $rank"
		) if ($useLogger);
		$i++;
	}
	return $ranking if ( !$parameters->{dontStoreRanking} );

}


=head2 createDefaultLogConfig($filename, $logLevel)

creates a simple log configuration for log4perl, usable with Log::Log4perl->init($config)

=cut

sub createDefaultLogConfig {
	my ($filename, $logLevel,$alsoToScreen, $synchronized) = @_;
	my $config = "";
	if ($alsoToScreen) {
	    $config .= "log4perl.rootLogger              = $logLevel, LOGFILE, LOGSCREEN\n";
	} else {
	    $config .= "log4perl.rootLogger              = $logLevel, LOGFILE\n";
	}
	$config .= qq(
log4perl.rootLogger.Threshold = OFF
log4perl.appender.LOGFILE           = Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename  = $filename
log4perl.appender.LOGFILE.mode      = write
log4perl.appender.LOGFILE.utf8      = 1
log4perl.appender.LOGFILE.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern = [%r] %d %p %m\t in %M (%F %L)%n
);
	if ($synchronized) {
		$config .= "log4perl.appender.LOGFILE.syswrite  = 1\n";
	}
	if ($alsoToScreen) {
		$config .= qq(
log4perl.appender.LOGSCREEN          = Log::Log4perl::Appender::Screen
log4perl.appender.LOGSCREEN.stderr   = 0
log4perl.appender.LOGSCREEN.layout   = PatternLayout
log4perl.appender.LOGSCREEN.layout.ConversionPattern = %p> %m%n
);
	}
	return \$config;
}




=head2 initLog($logConfigFileOrLevel, $logFilename)

initializes a log4perl object in the following way: if $logConfigFileOrLevel is a log level, then uses the
default config (directed to $logFilename), otherwise $logConfigFileOrLevel is supposed to be the log4perl
config file to be used.

=cut

sub initLog {
	my ($logConfigFileOrLevel, $logFilename, $alsoToScreen, $synchronized) = @_;
  	my $logLevel = undef;
#  	if (defined($logParam)) {
	if (grep(/^$logConfigFileOrLevel/, @possibleLogLevels)) {
		Log::Log4perl->init(createDefaultLogConfig($logFilename, $logConfigFileOrLevel, $alsoToScreen, $synchronized));
	} else {
		Log::Log4perl->init($logConfigFileOrLevel);
	}
}



=head2 readFileToHash ($filename, $colKey1, [$colKey2, ...], $colValue)

reads a tabular file and writes every value to a hash in the following way:
given a line with values <key1> [<key2>...] <val> respectively in columns $colKey1 [ $colKey2 ... ] $colValue, 
the resulting hash ref contains res->{key1}[->{key2}...] = val.
(simplest case: two columns, hash{col1} = col2).
Lines starting with # are skipped.

=cut

sub readFileToHash {
	confess("Error: readFileToHash requires at least 3 arguments.")
	  if ( scalar(@_) < 3 );
	my $filename = shift;

	#	my $colValue = pop;
	#	$colValue--;
	my @colsKeys = map { $_ - 1 } @_;

	#	print STDERR "DEBUG colKeys = ".join(";", @colsKeys)."\n";
	my $res = {};
	open( FILE, "<:encoding(utf-8)", $filename )
	  or die "can not open $filename";
	my $lineNo = 1;
	while (<FILE>) {
		if ( !m/^#/ ) {

			#			print STDERR "DEBUG reading $_";
			chomp;
			my @columns = split;
			$res = _addEntryToHashRec( $res, map { $columns[$_] } @colsKeys );
		}
		$lineNo++;
	}
	close(FILE);

	#	_printHash(*STDERR,$res, "");
	return $res;
}

sub _addEntryToHashRec {

	#	print STDERR "params = ".join("--",@_)."\n";
	my $hash  = shift;
	my $first = shift;
	confess("BUG!!!") if ( scalar(@_) < 1 );

	#	print STDERR "DEBUG REC: first=$first, others=".join(";",@_)."\n";
	if ( scalar(@_) == 1 ) {    # last item
		my $val = shift;

		#		print STDERR "  DEBUG REC END: $first -> $val\n";
		$hash->{$first} = $val;
	}
	else {
		if ( defined( $hash->{$first} ) ) {

			#		print STDERR "  DEBUG REC DEF\n";
			_addEntryToHashRec( $hash->{$first}, @_ );
		}
		else {

			#		print STDERR "  DEBUG REC UNDEF\n";
			$hash->{$first} = _addEntryToHashRec( {}, @_ );
		}
	}
	return $hash;
}

sub _printHash {
	my $fh     = shift;
	my $h      = shift;
	my $prefix = shift || "";
	if ( ref($h) eq "HASH" ) {
		foreach my $k ( keys %$h ) {
			print $fh "$prefix$k\n";
			_printHash( $fh, $h->{$k}, $prefix . "   " );
		}
	}
	else {
		print $fh "$prefix$h\n";
	}

}


#
# caution: arrays indexed from 1 by default
#
sub readTSVWithHeaderAsColumnsHash {
	my $filename = shift;
	my $logger = shift;
	my $indexFromZero = shift;
	if (!open( FILE, "<", $filename )) {
		$logger->logconfess("Can not read features stats in $filename.") if ($logger);
		die "Can not read features stats in $filename.";
	}
	my @content;
	my $first = 1;
	while (<FILE>) {
	    chomp;
	    my @cols = split "\t";
	    if ($first) {                                        # header
		$first = 0;
		for ( my $i = 0 ; $i < scalar(@cols) ; $i++ ) {
#		    print "DEBUG A $cols[$i]\n";
		    if ($cols[$i] =~ m/^".*"$/) {
			$cols[$i] = substr($cols[$i],1,-1);
#			print "DEBUG B $cols[$i]\n";
		    }
		    $content[$i] = [ $cols[$i] ]; # index 0 will not be used, temporarily used to store header
		}
	    }
	    else {
		for ( my $i = 0 ; $i < scalar(@cols) ; $i++ ) {
		    push( @{ $content[$i] }, $cols[$i] );
		}
	    }
	}
	close(FILE);
	my %res;
	for ( my $i = 0 ; $i < scalar(@content) ; $i++ ) { # 
	    my $colName = $content[$i]->[0] ;
		if ($indexFromZero) {
		    shift(@{$content[$i]});
		} else {
		    $content[$i]->[0]=undef;
		}
		$res{$colName} = $content[$i];
	}
	return \%res;
}


#
# format variableName=value
# comments (starting with #) and empty lines allowed
# returns a hash
#
sub readConfigFile {
	my $filename=shift;
	open( FILE, "<", $filename ) or die "Can not read config file $filename.";
	my %res;
	while (<FILE>) {
	    #print "debug: $_";
	    chomp;
	    if (m/#/) {
		s/#.*$//;  # remove comments
	    }
	    s/^\s+//; # remove spaces
	    s/\s+$//; 
	    if ($_) {
		my ($name, $value) = ( $_ =~ m/([^=]+)=(.*)/);
		$res{$name} = $value;
#		print "debug: '$name'->'$value'\n";
	    }
	}
	close(FILE);
	return \%res;
}


=head2 mean(@$values, $naStr)

returns the arithmetic mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
$naStr is used instead of undef if it is defined.

=cut

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


=head2 stdDev(@$values, $naStr)

returns the std dev of the values, not taking into account undefined values, and returns undef in no defined values at all.
$naStr is used instead of undef if it is defined.

=cut

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


=head2 median(@$values, $naStr)

returns the median of the values, not taking into account undefined values, and returns undef in no defined values at all.
$naStr is used instead of undef if it is defined.

=cut

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


=head2 geomMean(@$values, $naStr)

returns the geometric mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
$naStr is used instead of undef if it is defined.

=cut

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


=head2 geomMean(@$values, $naStr)

returns the harmonic mean of the values, not taking into account undefined values, and returns undef in no defined values at all.
$naStr is used instead of undef if it is defined.
Zero values are not ignored: if there is a zero value, the result is undef (or $naStr)

=cut

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

=head2 means(@$values, $naStr)

returns the arithmetic, geometric and harmonic mean of the values (following the exceptions defined form each function) in a hash.
$naStr is used instead of undef if it is defined.

=cut

sub means {
    my $values = shift;
    my $naStr = shift;
    my $res = { "arithm" => mean($values, $naStr) ,  "geom" => geomMean($values, $naStr) , "harmo" => harmoMean($values, $naStr) };
#    print STDERR "DEBUG MEANS values = ".join(" ; ", @$values)."... results = ".join(" ; ", (values %$res))."\n";
    return $res;
}


=head2 means(@$values, $aggregType, $naStr)

returns the value corresponding to the statistic described by $aggregType: median, arithm, geom, harmo for the array ref $values.
$naStr is used instead of undef if it is defined.

=cut

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



#
# warning: if $naStr is defined, ignores NaN values
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


sub max {
    my $values = shift;
    my $naStr = shift;
    my $max=undef;
    foreach my $v (@$values) {
	if (defined($v) && (!defined($naStr) || ($v ne $naStr))) {
	    $max = $v if (!defined($max) || ($v>$max));
	}
    }
    return (defined($max)) ? $max : ( defined($naStr) ? $naStr : undef );
}

sub readFileAsTokensList {
	my $f = shift;
	my $logger = shift;
	if(!open(FILE,"<", $f)) {
		$logger->logconfess("Can not open file $f") if ($logger);
		die "Can not open file $f" # if no logger
	}
	my @content;
	while (<FILE>) {
		chomp;
		my @tokens = split;
		push(@content, @tokens);
	}
	close(FILE); 
	return \@content;
}


sub pickInList {
	my $list = shift;
#	print Dumper($list);
	confess "Wrong parameter: not an array or empty array" if ((ref($list) ne "ARRAY") || (scalar(@$list)==0));
	return $list->[int(rand(scalar(@$list)))];
}


sub pickInListProbas {
	my $areaByValue = shift;
	confess "Wrong parameter: not a hash or empty hash" if ((ref($areaByValue) ne "HASH") || (scalar(keys %$areaByValue)==0));
	my $areaTotal = 0;
	while (my ($item, $area) = each %$areaByValue) {
		$areaTotal += $area;
#	    print STDERR "DEBUG $item : $area (total = $areaTotal)\n";
	}
	my $rndProba = rand($areaTotal);
	$areaTotal = 0;
	while (my ($item, $area) = each %$areaByValue) {
		$areaTotal += $area;
#	    print STDERR "DEBUG $item : $area (total = $areaTotal, random = $rndProba)\n";
		return $item if ($rndProba < $areaTotal); 
	}
	die "BUG should never have arrived here";
}


# TODO
sub pickInListProbasBak {
	my $list = shift;
	my $areaByValue = shift;
	my $areaTotal = 0;
	my @unseen;
	foreach my $item (@$list) {
		if (defined($areaByValue->{$item})) {
			$areaTotal += $areaByValue->{$item};
		} else {
			push(@unseen, $item) ;
		}  
	}
	return $unseen[int(rand(scalar(@unseen)))] if (scalar(@unseen)>0); # some items were never seen before: pick one randomly
	my $rndProba = rand($areaTotal);
	$areaTotal = 0;
	foreach my $item (@$list) {
		$areaTotal += $areaByValue->{$item};
		return $item if ($rndProba < $areaTotal); 
	}
	die "BUG should never have arrived here";
}



sub pickNAmongSloppy {
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


# returns an array ref: matrix->[col]->[line]
sub readTSVByColumnsNoHeader {
	my $f = shift;
	my $sep = shift;
	my $indexFirstLine = shift;
	my $logger = shift;
	my $onlyTheseIndexes = shift ; # OPTIONAL
	if (!open(FILE, "<:encoding(utf-8)", $f)) {
		$logger->logconfess("can not open file $f") if ($logger);
		die "can not open file $f";
	}
	my @columns;
	my $lineNo = defined($indexFirstLine) ? $indexFirstLine : 0; 
	my $metaIndex=0;
	my $nextIndex = undef;
	if (defined($onlyTheseIndexes)) {
	    $nextIndex = ($metaIndex < scalar(@$onlyTheseIndexes)) ? $onlyTheseIndexes->[$metaIndex] : -1;
	}
	while (<FILE>) {
	    if (!defined($nextIndex) || ($lineNo == $nextIndex)) {
		chomp;
		my @cols = defined($sep) ? split($sep, $_) : split ;
		for (my $i=0; $i<scalar(@cols); $i++) {
		    $columns[$i]->[$lineNo] = $cols[$i];
		}
		if (defined($nextIndex)) {
		    $metaIndex++;
		    $nextIndex = ($metaIndex < scalar(@$onlyTheseIndexes)) ? $onlyTheseIndexes->[$metaIndex] : -1;
		}
	    }
	    $lineNo++;
	}
	close(FILE);
	return \@columns;
}


# return a value nthBin: 0 <= nthBin < nbBins
sub discretize {
    my ($val, $nbBins, $min, $max) =  @_;

    return $nbBins-1 if ($val==$max);
    my $size  = ($max-$min) / $nbBins;
    my $binVal = ($val - $min ) / $size;
    return int($binVal);

}


## should not be here
sub selectMFValueCriterion {
	my $mfData = shift;
	my $mfValue = shift;
	my $criterion = shift;
	if (defined($mfData->{$mfValue})) {
		if ($criterion eq "mean") {
			return $mfData->{$mfValue}->{sum} / $mfData->{$mfValue}->{nb} ;
		} elsif ($criterion eq "max") {
			return $mfData->{$mfValue}->{max} ;
		} else {
			die "BUG: invalid selection criterion id";
		}
	} else {
		return undef;
	}
}


sub writeFileLineByLine {
	my $lines = shift;
	my $filename = shift;
	
	open(FILE, ">:encoding(utf-8)", $filename) or confess("Can not open file '$filename' for writing");
	foreach my $l (@$lines) {
		print FILE "$l\n";
	}
	close(FILE);
}


1;
