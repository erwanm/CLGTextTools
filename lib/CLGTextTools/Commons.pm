package CLGTextTools::Commons;

use strict;
use warnings;
use Log::Log4perl;
use Carp;
use File::BOM qw/open_bom/;
use CLGTextTools::Logging qw/confessLog/;

use base 'Exporter';
our @EXPORT_OK = qw/readTextFileLines readLines arrayToHash/;




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



1;
