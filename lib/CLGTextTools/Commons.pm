package CLGTextTools::Commons;

use strict;
use warnings;
use Log::Log4perl;
use Carp;
use File::BOM qw/open_bom/;
use CLGTextTools::Logging qw/confessLog warnLog cluckLog/;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw/readTextFileLines readLines arrayToHash hashKeysToArray readTSVByLine readTSVFileLinesAsArray readTSVLinesAsArray readConfigFile parseParamsFromString readTSVFileLinesAsHash readTSVLinesAsHash getArrayValuesFromIndexes containsUndef mergeDocs readObsTypesFromConfigHash readParamGroupAsHashFromConfig assignDefaultAndWarnIfUndef rankWithTies/;




sub openFileBOM {
    my $file = shift;
    my $logger = shift; # optional

    my $fh;
    # apparently open_bom fails if there is no BOM, hence the complicated eval (don't see why actually)
    eval {
        open_bom($fh, $file, ':encoding(UTF-8)') or die;
    };
    if ($@) {
        open($fh, '<:encoding(UTF-8)', $file) or confessLog($logger, "Cannot open '$file' for reading");
	$logger->trace("Opening file '$file'") if ($logger);
    } else {
	$logger->trace("Opening file '$file' (BOM found)") if ($logger);
    }
    return $fh;
}


#
# given an array [ a, b, c ], returns a hash { a => 1, b => 1, c => 1 }
#
sub arrayToHash {
    my $array = shift;
    my %hash = map { $_ => 1 } @$array;
    return \%hash;
}



sub hashKeysToArray {
    my $hash = shift;
    my @keys = keys %$hash;
    return \@keys;
}


sub readTextFileLines {
    my $file = shift;
    my $removeLineBreaks = shift;
    my $logger = shift; # optional

    my $fh = openFileBOM($file, $logger);
    $logger->debug("Reading text file '$file'") if ($logger);
    my $content = readLines($fh, $removeLineBreaks, $logger);
    close($fh);
    return $content;
}


sub readLines {
    my $fh = shift;
    my $removeLineBreaks = shift;
    my $logger = shift; # optional

    my @content;
    while (<$fh>) {
	chomp if ($removeLineBreaks);
#	$logger->trace("Reading line '$_'") if ($logger);
	push(@content, $_);
    }
    return \@content;
}



#
# $checkNbCols: if >0, checks that every line contains this number of columns.
#
#
sub readTSVFileLinesAsArray {
    my $file = shift;
    my $checkNbCols = shift;
    my $logger = shift; # optional

    my $fh;
    open($fh, '<:encoding(UTF-8)', $file) or confessLog($logger, "Cannot open '$file' for reading");
    $logger->debug("Reading text file '$file'") if ($logger);
    my $content = readTSVLinesAsArray($fh, $file, $checkNbCols, $logger);
    close($fh);
    return $content;
}


#
# $checkNbCols: if >0, checks that every line contains this number of columns.
# return value: array->[$row]->[$column]
#
sub readTSVLinesAsArray {
    my $fh = shift;
    my $filename = shift; # set to undef if not a file or doesn't matter - used ony for error mesg
    my $checkNbCols = shift; # optional
    my $logger = shift; # optional
    $checkNbCols = 0 if (!defined($checkNbCols));
    
    my @lines;
    my $index = 0;
    while (<$fh>) {
	chomp;
	my @columns = split(/\t/);
#	$logger->trace("Reading line '$_'") if ($logger);
	confessLog($logger, "Error: wrong number of columns: expected $checkNbCols but found ".scalar(@columns)." in '$filename', line ".($index+1)."") if (($checkNbCols > 0) && (scalar(@columns) != $checkNbCols));
	push(@lines, \@columns);
	$index++;
    }
    return \@lines;
}


#
# 
#
#
sub readTSVFileLinesAsHash {
    my $file = shift;
    my $logger = shift; # optional

    my $fh;
    open($fh, '<:encoding(UTF-8)', $file) or confessLog($logger, "Cannot open '$file' for reading");
    $logger->debug("Reading text file '$file'") if ($logger);
    my $content = readTSVLinesAsHash($fh, $file, $logger);
    close($fh);
    return $content;
}


#
# return value: hash->{col1} = col2
# checks that there are exactly two columns on every line. The first column must not contain any duplicate.
#
sub readTSVLinesAsHash {
    my $fh = shift;
    my $filename = shift; # set to undef if not a file or doesn't matter - used ony for error mesg
    my $logger = shift; # optional

    my %res;
    my $index = 0;
    while (<$fh>) {
	chomp;
	my @columns = split(/\t/);
#	$logger->trace("Reading line '$_'") if ($logger);
	confessLog($logger, "Error: wrong number of columns: expected 2 but found ".scalar(@columns)." in '$filename', line ".($index+1)."") if (scalar(@columns) != 2);
	$res{$columns[0]} = $columns[1];
	$index++;
    }
    return \%res;
}



#
# format: variableName=value
# comments (starting with #) and empty lines allowed
# returns a hash res->{variableName} = value
#
sub readConfigFile {
    my $filename=shift;
    open( FILE, '<:encoding(UTF-8)', $filename ) or die "Cannot read config file '$filename'.";
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
            #print "debug: '$name'->'$value'\n";
	}
    }
    close(FILE);
    return \%res;
}


#
# Reads a string of the form "param1=value1[;param2=value2;...]" and returns a hash res->{paramX} = valueX
# If a hash ref is provided as 2nd arg, them the key/value pairs are added to this hash (overwriting a value if the key exists)
#
#
sub parseParamsFromString {
    my $s = shift;
    my $res = shift; # optional
    my $logger = shift; # optional
    my $separatorEqual = shift;  # optional

    $res = {} if (!defined($res));
    my @nameValuePairs = split(";", $s);
    foreach my $nameValuePair (@nameValuePairs) {
	my ($name, $value) = ( $nameValuePair =~ m/([^$separatorEqual]+)$separatorEqual(.*)/);
	if (defined($name) && defined($value)) {
	    $res->{$name} = $value;
	} else {
	    confessLog($logger, "Cannot parse string '$s' as '<name>$separatorEqual<value>'");
	}
    }
    return $res;
}



sub getArrayValuesFromIndexes {
    my $array = shift;
    my $indexes = shift;

    my @res = map { $array->[$_] } @$indexes;
    return \@res;

}



# containsUndef($list)
#
# $list is a list ref or undef.
# Returns 1 if list is undefined or contains an undef value.
#
sub containsUndef {
    my $l = shift;
#    print STDERR "list undef ?\n";
    return 1 if (!defined($l));
 #   print STDERR "list not undef\n";
    foreach my $e (@$l) {
	return 1 if (!defined($e));
    }
    return 0;
}


#
#
# * $overwrite: optional, if true the result doc overwrites the doc with the highest number of distinct observations (might be faster).
#
sub mergeDocs {
    my ($doc1, $doc2, $overwrite) = @_;
    
    my ($largest, $smallest);
    if (scalar(keys(%$doc1)) > scalar(keys(%$doc2))) {
	($largest, $smallest) = ($doc1, $doc2);
    } else {
	($largest, $smallest) = ($doc2, $doc1);
    }
    my $res;
    if ($overwrite) {
	$res = $largest;
    } else {
	%$res = %$largest;
    }
    my ($obs, $nb);
    while (($obs, $nb) = each %$smallest) {
	$res->{$obs} += $nb;
    }
    return $res;
}


sub readObsTypesFromConfigHash {
    my $params = shift;

    my @obsTypesList;
    if (defined($params->{obsTypes})) {
	@obsTypesList = split(":", $params->{obsTypes});
    } else {
	foreach my $p (keys %$params) {
	    if ($p =~ m/^obsType\./) {
		my ($obsType) = ($p =~ m/^obsType\.(.+)$/);
		push(@obsTypesList, $obsType) if ($params->{$p});
	    }
	}
    }
    return \@obsTypesList;
}


#
# Given a "config hash" params->{name} = value, extracts all parameters where name is prefix.subname = value
# under the form of a hash: res->{subname} = value
#
sub readParamGroupAsHashFromConfig {
    my $params = shift;
    my $prefix = shift;
    my $keepOtherParams = shift; # optional
    my $separator = shift; # as a regexp; optional

    $separator = "\." if (!defined($separator));

    my %res;
    foreach my $p (keys %$params) {
#	print STDERR "DEBUG readParamGroupAsHashFromConfig 1: p='$p'\n";
	if ($p =~ m/^${prefix}${separator}/) {
	    my ($name)  = ($p =~ m/^${prefix}${separator}(.+)$/);
	    $res{$name} = $params->{$p};
#	    print STDERR "DEBUG readParamGroupAsHashFromConfig 2: name='$name', value='$res{$name}'\n";
	} else {
	    $res{$p} = $params->{$p} if ($keepOtherParams);
	}
    }    
    return \%res;
}



sub assignDefaultAndWarnIfUndef {
    my $paramId = shift;
    my $value = shift;
    my $default = shift;
    my $logger = shift; # optional

    if (!defined($value)) {
	warnLog($logger, "No value provided for parameter '$paramId', using default '$default'");
	$value = $default;
    }
    return $value;
}




# rankWithTies($parameters)
#
# Computes a ranking which takes ties into account, i.e. two identical values are assigned the same rank.
# The sum property is also fulfilled, i.e. the sum of all ranks is always 1+2+...+N (if first rank is 1). This implies
# that the rank assigned to several identical values is the average of the ranks they would have been assigned if ties were not taken into account.
# 
# $parameters is a hash which must define:
# * values: a hash ref of the form $values->{id} = value. Can contain NaN values, but these values will be ignored.
# and optionally defines:
# * array: if defined, an array ref which contains the ids used as keys in values
# * arrayAlreadySorted: (only if array is defined, see above). if set to true, "array" must be already sorted. the sorting step
#   will not be done (this way it is possible to use any kind of sorting) (the ranking step - with ties - is still done of course) 
# * highestValueFirst: false by default. set to true in order to rank from highest to lowest values. Useless if array is defined. 
# * printToFileHandle: if defined, a file handle where ranks will be printed.
# * dontPrintValue: if defined and if printToFileHandle is defined, then lines are of the form
#  "<id> [otherData] <rank>"  instead of "<id> [otherData] <value> <rank>".
# 
# * otherData: hash ref of the form $otherData->{$id}=data. if defined and if printToFileHandle is defined, then lines
#   like "<id> <otherData> [value] <rank>" will be written to the file instead of "<id> [value] <rank>". if the "data" contains
#   several columns, these columns must be already separated together but should not contain a column separator at the beginning
#   or at the end.  
# * columnSeparator: if defined and if printToFileHandle is defined, will be used as column separator (tabulation by default). 
# * noNaNWarning: 0 by default, which means that a warning is issued if NaN values are found. This does not happen if this parameter
#   is set to true. not used if $array is defined.
# * dontStoreRanking: By default the returned value is a hash ref of the form $ranking->{id}=rank containing the whole ranking. 
#  If dontStoreRanking is true then nothing is returned. 
# * firstRank: rank starting value (1 by default).
# * addNaNValuesBefore: boolean, default 0. by default NaN values are discarded. If true, these values are prepended to the ranking (before first real value).
# * addNaNValuesAfter: boolean, default 0. by default NaN values are discarded. If true, these values are appended to the ranking (after last real value).
#
sub rankWithTies {

	my ($parameters, $logger) = @_;
	my $firstRank = defined( $parameters->{firstRank} ) ? $parameters->{firstRank} : 1;
	my $colSep = defined( $parameters->{columnSeparator} ) ? $parameters->{columnSeparator} : "\t";
	my $values = $parameters->{values};
	confessLog($logger, "Error: \$parameters->{values} must be defined.") if ( !defined($values) );
	my $array = $parameters->{array};
	if ( !defined($array) || !$parameters->{arrayAlreadySorted} ) {
		my @sortedIds;
		if ( $parameters->{highestValueFirst} ) {
			$logger->debug("Sorting by descending order (highest value first)") if ($logger);
			@sortedIds =
			  sort { $values->{$b} <=> $values->{$a} }
			  grep { $values->{$_} == $values->{$_} }
			  defined($array)
			  ? @$array
			  : keys %$values
			  ; # tricky: remove the NaN values before sorting. found in perl man page for sort.
		} else {
			$logger->debug("Sorting by ascending order (lowest value first)") if ($logger);
			@sortedIds =
			  sort { $values->{$a} <=> $values->{$b} }
			  grep { $values->{$_} == $values->{$_} }
			  defined($array)
			  ? @$array
			  : keys %$values
			  ; # tricky: remove the NaN values before sorting. found in perl man page for sort.
		}
		if (   $parameters->{addNaNValuesBefore} || $parameters->{addNaNValuesAfter} ) {
			my @NaNIds =
			  grep { $values->{$_} != $values->{$_} }
			  defined($array) ? @$array : keys %$values;
			my $nbValues    = scalar( keys %$values );
			my $nbNaNValues = scalar(@NaNIds);
			if ( scalar($nbNaNValues) > 0 ) {
				if ( $parameters->{addNaNValuesBefore} ) {
					unshift( @sortedIds, @NaNIds );
					if ( !$parameters->{noNaNWarning} ) {
					    if ($logger) {
						$logger->logwarn("$nbNaNValues NaN values (among $nbValues) prepended to ranking.") ;
					    } else {
						warn("$nbNaNValues NaN values (among $nbValues) prepended to ranking.") ;
					    }
					}
				}
				else {
					push( @sortedIds, @NaNIds );
					if ( !$parameters->{noNaNWarning} ) {
					    if ($logger) {
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
			warnLog($logger, "$nbNaNValues NaN values (among $nbValues) discarded from ranking." ) if ( $nbNaNValues > 0 );
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
				my $otherData =  defined( $parameters->{otherData} ) ? $colSep . $parameters->{otherData}->{ $array->[$j] } : "";
				my $valueData =  $parameters->{dontPrintValue}  ? "" : $colSep . $values->{ $array->[$j] };
				print $fh $array->[$j] . $otherData . $valueData . $colSep . $rank . "\n";
			}
			if ( !$parameters->{dontStoreRanking} ) {
				$ranking->{ $array->[$j] } = $rank;
			}
		}
		$logger->debug("found $nbTies ties starting at position $currentFirst+1, assigned rank is $rank") if ($logger);
		$i++;
	}
	return $ranking if ( !$parameters->{dontStoreRanking} );

}



1;
