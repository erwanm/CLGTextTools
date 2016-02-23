package CLGTextTools::DocProvider;

# EM Oct 2015
# 
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog/;
use CLGTextTools::Commons qw/readTSVFileLinesAsHash readTSVFileLinesAsArray/;
use CLGTextTools::ObsCollection;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw//;



#
# a DocProvider is a wrapper for a document represented as an ObsCollection, but which loads the data only when needed (lazy loading)
#
# $params:
# * logging
# the obs collection parameters are provided either as:
# ** obsCollection: an ObsCollection object (initialized)
# ** all the parameters required to initiate a new ObsCollection object (see CLGTextTools::ObsCollection):
# *** obsTypes (list or colon-separated string)
# *** wordTokenization
# *** wordVocab
# *** formatting
# * filename
# * useCountFiles: if defined and not zero or empty string, then the instance will try to read observations counts from files filename.<obs>.count; if these files don't exist, then the source document is read and the count files are written. If undef (or zero etc.), then no count file is ever read or written. 
#


sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	$self->{logger}->debug("Initializing DocProvider for '".$params->{filename}."'") if ($self->{logger});
 	$self->{filename} = $params->{filename};
	confessLog($self->{logger}, "Error: file '".$self->{filename}."' not found.") if (! -f $self->{filename});
	$self->{obsCollection} = (defined($params->{obsCollection})) ? $params->{obsCollection} : CLGTextTools::ObsCollection->new($params) ;
	$self->{obsTypesList} = $self->{obsCollection}->getObsTypes();
	confessLog($self->{logger}, "obs types list undefined or empty") if (!defined($self->{obsTypesList}) || (scalar(@{$self->{obsTypesList}}) == 0));
	$self->{useCountFiles} = $params->{useCountFiles};
	$self->{observs} = undef;
	$self->{nbObsDistinct} = {};
	$self->{nbObsTotal} = {};
	bless($self, $class);
	return $self; 	
}


sub getFilename {
    my $self = shift;
    return $self->{filename};
}


#
# forces populating the document (using count files or source file)
#
#
sub populate {
    my $self = shift;

    $self->{logger}->debug("populating observations for '".$self->{filename}."'...") if ($self->{logger});
    my %observs;
    my $writeCountFiles=0;
    my $prefix = $self->{filename};
    if (($self->{useCountFiles}) && (-f "$prefix.".$self->{obsTypesList}->[0].".count")) {  # assuming that either all count files are present, or none
	$self->{logger}->trace("count file found, going to read from files") if ($self->{logger});
	$self->readCountFiles();
    } else { # either usecount=0 or count files not present
	$self->{logger}->trace("option disabled or count file not found, going to read from source doc") if ($self->{logger});
	$self->readSourceDoc();
	if ($self->{useCountFiles}) { # if usecount=1 here, then count files were not present: write them
	    $self->writeCountFiles();
	}
    }
}


# 
# returns observs->{obs} = freq
# if $obsType is not specified, returns the whole collection: observs->{obsType}->{obs} = freq
#
sub getObservations {
    my $self = shift;
    my $obsType = shift;

    $self->{logger}->debug("obtaining observation for '".$self->{filename}."', obsType = ".(defined($obsType)?$obsType:"undef (all)")) if ($self->{logger});
    $self->populate() if (!defined($self->{observs}));
    if (defined($obsType)) {
	confessLog($self->{logger}, "Error: invalid observation type '$obsType'; no such type found in the collection.") if (!defined($self->{observs}->{$obsType}));
	return $self->{observs}->{$obsType};
    } else {
	return $self->{observs} ;
    }
}



#
#
#
sub readCountFiles {
    my $self = shift;

    $self->{logger}->debug("reading from count files...") if ($self->{logger});
    my $prefix = $self->{filename};
    foreach my $obsType (@{$self->{obsTypesList}}) {
	my $f = "$prefix.$obsType.count";
	$self->{logger}->debug("obs type $obsType: reading count file '$f'") if ($self->{logger});
	my $a = readTSVFileLinesAsArray("$f.total", 2, $self->{logger});
	$self->{nbObsDistinct}->{$obsType} = $a->[0]->[0];
	$self->{nbObsTotal}->{$obsType} = $a->[0]->[1];
	$self->{observs}->{$obsType} = readTSVFileLinesAsHash($f, $self->{logger});
	$self->{logger}->debug("obs type $obsType: read ".$self->{nbObsTotal}->{$obsType}." observations") if ($self->{logger});
#	$self->{logger}->trace("obs type $obsType: ".scalar(keys %{$self->{observs}->{$obsType}})." observations in hash") if ($self->{logger});
    }

}



#
# writes <prefix>.<obs>.count and <prefix>.<obs>.total for every obs type
# called from populate if useCountFiles=1; otherwise, must be used after calling getObservations()
#
sub writeCountFiles {
    my $self = shift;
    my $columnObsType = shift; # optional, prints the obs type first on each line if defined.

    my $prefix = $self->{filename};
    $self->{logger}->debug("Writing count files to '$prefix.<obsType>.count'") if ($self->{logger});
    foreach my $obsType (@{$self->{obsTypesList}}) {
	$self->{logger}->debug("Writing count file: '$prefix.$obsType.count'") if ($self->{logger});
	my $f = "$prefix.$obsType.count";
	my $fh;
	open($fh, ">:encoding(utf-8)", $f) or confessLog($self->{logger}, "Cannot open file '$f' for writing");
	my $observs = $self->{observs}->{$obsType};
	$self->{logger}->debug("Writing observations for obs type '$obsType'") if ($self->{logger});
	while (my ($key, $nb) = each %$observs) {
	    print $fh "$obsType\t" if ($columnObsType);
	    printf $fh "%s\t%d\n", $key, $nb ;
	}
	close($fh);
	$f = "$prefix.$obsType.count.total";
	open($fh, ">:encoding(utf-8)", $f) or confessLog($self->{logger}, "Cannot open file '$f' for writing");
	printf $fh "%d\t%d\n", $self->{nbObsDistinct}->{$obsType}, $self->{nbObsTotal}->{$obsType};
	close($fh);
    }
}



sub readSourceDoc {
    my $self = shift;

    $self->{logger}->debug("reading observations from source doc for '".$self->{filename}."'.") if ($self->{logger});
    $self->{obsCollection}->extractObsFromText($self->{filename});
    $self->{obsCollection}->finalize();
    $self->{observs} = $self->{obsCollection}->getObservations($self->{obsTypesList});
    foreach my $obsType (@{$self->{obsTypesList}}) {
	$self->{nbObsDistinct}->{$obsType} = $self->{obsCollection}->getNbDistinctNGrams($obsType);
	$self->{nbObsTotal}->{$obsType} = $self->{obsCollection}->getNbTotalNGrams($obsType);
	$self->{logger}->debug("".$self->{nbObsTotal}->{$obsType}." observations for '$obsType'") if ($self->{logger});

    }
}




1;
