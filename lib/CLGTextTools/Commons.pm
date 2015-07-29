package CLGTextTools::Commons;

use strict;
use warnings;
use Log::Log4perl;
use Carp;
use File::BOM qw/open_bom/;
use CLGTextTools::Logging qw/confessLog/;

use base 'Exporter';
our @EXPORT_OK = qw/readTextFileLines readLines arrayToHash hashKeysToArray readTSVByLine readTSVFileLinesAsArray readTSVLinesAsArray/;




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
    my $checkNbCols = shift;
    my $logger = shift; # optional

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


1;
