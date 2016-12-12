package CLGTextTools::DocProvider;

#twdoc
#
# ``DocProvider`` is a wrapper for a document represented as an ``ObsCollection``, but which computes or loads the data only when needed (lazy loading).
#
# The computing/loading of the data is triggered  when the calling program calls ``getObservations()``, ``getNbObsDistinct()`` or ``getNbObsTotal()`` for the first time. 
# If the option ``useCountFiles`` is false, the data can only be computed from the source document. If ``useCountFiles`` is true, then:
#
# * if the count file(s) exist(s) on disk, load from disk;
# * if not, compute from the source document and then write the  count files to disk (for possible future use).
#
# Remark: if the data is loaded from the count files, then the underlying ``ObsCollection`` object is not actually used.
#
# ---
# EM Oct 2015
# 
#/twdoc


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



#twdoc new($class, $params)
#
# ``$params``:
#
# * logging
# * the obs collection parameters are provided either as:
# ** obsCollection: an ObsCollection object (initialized)
# ** all the parameters required to initiate a new ObsCollection object (see CLGTextTools::ObsCollection):
# *** obsTypes (list or colon-separated string)
# *** wordTokenization
# *** wordVocab
# *** formatting
# *** optional: if the obs collection has been finalized (i.e. has been populated), then the document is considered loaded regardless of the existence of corresponding count files.
# * filename
# * id (optional; filename will be used if undef)
# * useCountFiles: if defined and not zero or empty string, then the instance will try to read observations counts from files ``filename.observations/<obs>.count``; if these files don't exist, then the source document is read and the count files are written. If undef (or zero etc.), then no count file is ever read or written. 
# * forceCountFiles: optional. if useCountFiles is true and the count files already exist, they are not used and the source doc is re-analyzed, then the count files are overwritten.
# * checkIfSourceDocExists: optional, default 1.
#
#/twdoc
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	$self->{logger}->debug("Initializing DocProvider for '".$params->{filename}."'") if ($self->{logger});
	confessLog($self->{logger}, "parameter 'filename' must be defined") if (!defined($params->{filename}));
 	$self->{filename} = $params->{filename};
 	$self->{id} = (defined($params->{id})) ? $params->{id} : $params->{filename};
	$self->{useCountFiles} = defined($params->{useCountFiles}) ? 1 : 0;
	$self->{forceCountFiles} = defined($params->{forceCountFiles}) ? 1 : 0;
	$self->{checkIfSourceDocExists} = defined($params->{checkIfSourceDocExists}) ? $params->{checkIfSourceDocExists} : 1 ;
	$self->{obsCollection} = (defined($params->{obsCollection})) ? $params->{obsCollection} : CLGTextTools::ObsCollection->new($params) ;
	$self->{obsTypesList} = $self->{obsCollection}->getObsTypes();
	confessLog($self->{logger}, "obs types list undefined or empty") if (!defined($self->{obsTypesList}) || (scalar(@{$self->{obsTypesList}}) == 0));
	if ($self->{obsCollection}->isFinalized()) {
	    $self->{observs} = $self->{obsCollection}->getObservations($self->{obsTypesList});
	    foreach my $obsType (@{$self->{obsTypesList}}) {
		$self->{nbObsDistinct}->{$obsType} = $self->{obsCollection}->getNbDistinctNGrams($obsType);
		$self->{nbObsTotal}->{$obsType} = $self->{obsCollection}->getNbTotalNGrams($obsType);
		confessLog($self->{logger}, "Error: nb distinct obs not defined for finalized obs coll") if (!defined($self->{nbObsDistinct}->{$obsType}));
		confessLog($self->{logger}, "Error: nb total obs not defined for finalized obs coll") if (!defined($self->{nbObsTotal}->{$obsType}));
	    }
	} else {
	    if ($self->{checkIfSourceDocExists}) {
		confessLog($self->{logger}, "Error: file '".$self->{filename}."' not found.") if (! -f $self->{filename}); # only in case doc not finalized (otherwise no need for the source doc, which might not exist)
	    }
	    $self->{observs} = undef;
	    $self->{nbObsDistinct} = {};
	    $self->{nbObsTotal} = {};
	}
	bless($self, $class);
	return $self; 	
}



#twdoc getFilename($self)
#
#
#/twdoc
sub getFilename {
    my $self = shift;
    return $self->{filename};
}


#twdoc getId($self)
#
#
#/twdoc
sub getId {
    my $self = shift;
    return $self->{id};
}



#twdoc getCoutFileName($self, $obsType)
#
# returns the filename where observations are read/written if useCountFile is true.
#
#/twdoc
sub getCountFileName {
    my $self = shift;
    my $obsType = shift;
    
    my $prefix = $self->{filename};
    mkdir "$prefix.observations" if (! -d "$prefix.observations");
    return "$prefix.observations/$obsType.count";
}


#twdoc allCountFilesExist($self)
#
# returns true if the count files for all observations types exist on disk.
#
#/twdoc
sub allCountFilesExist {
    my $self = shift;

    foreach my $obsType (@{$self->{obsTypesList}}) {
	return 0 if (! -f $self->getCountFileName($obsType));
    }
    return 1;
}



#twdoc populate($self, ?$obsType)
#
# Forces populating the document (using count files or source doc).
#
#/twdoc
sub populate {
    my $self = shift;
    my $obsType = shift; # optional

    $self->{logger}->debug("populating observations for '".$self->{filename}."', useCountFiles=".$self->{useCountFiles}) if ($self->{logger});
    my %observs;
    my $writeCountFiles=0;
    if ($self->{useCountFiles} && !$self->{forceCountFiles} && ((defined($obsType) && -f $self->getCountFileName($obsType)) || $self->allCountFilesExist() )   )  {
	$self->{logger}->trace("count file(s) found, going to read from file(s)") if ($self->{logger});
	if (defined($obsType)) {
	    $self->readCountFile($obsType);
	} else {
	    $self->readCountFiles();
	}
    } else { # either usecount=0 or (some) count files not present or force is true
	# in case $obsType is undef,  assuming that either all count files are present, or none
	# disadvantage: if some files exist and some are missing, everything is recomputed (including if only one is missing).
	$self->{logger}->trace("option disabled or count file not found, going to read from source doc") if ($self->{logger});
	$self->readSourceDoc();
	if ($self->{useCountFiles}) { # if usecount=1 here, then count files were not present: write them
	    $self->{logger}->trace("option count files enabled, going to write observations to file") if ($self->{logger});
	    $self->writeCountFiles();
	}
    }
}



#twdoc obsTypeInList($self, $obsType)
#
# Returns true if ``$obsType`` belongs to the list of obs types.
#
#/twdoc
sub obsTypeInList {
    my $self = shift;
    my $obsType = shift;

    $self->{logger}->debug("checking if '$obsType' belongs to the lsit of obs types") if ($self->{logger});
    return ( grep { $obsType eq $_ } @{$self->{obsTypesList}} );
}


#twdoc getObservations($self, ?$obsType)
# 
# returns a hash ``$observs``: ``$observs->{obs} = freq``. if ``$obsType`` is not specified, returns the whole collection: ``$observs->{obsType}->{obs} = freq``
#
#/twdoc
sub getObservations {
    my $self = shift;
    my $obsType = shift;

    $self->{logger}->debug("obtaining observation for '".$self->{filename}."', obsType = ".(defined($obsType)?$obsType:"undef (all)")) if ($self->{logger});
    if (defined($obsType)) {
	$self->populate($obsType) if (!defined($self->{observs}->{$obsType}));
	confessLog($self->{logger}, "Error: invalid observation type '$obsType'; no such type found in the collection.") if (!defined($self->{observs}->{$obsType}));
	return $self->{observs}->{$obsType};
    } else {
	$self->populate() if (!defined($self->{observs}));
	return $self->{observs} ;
    }
}


#twdoc getObsTypesList($self)
#
# Returns the list of obs types
#
#/twdoc
sub getObsTypesList {
    my $self = shift;
    return $self->{obsCollection}->getObsTypes();
}



#twdoc getNbObsDistinct($self, ?$obsType)
#
# Returns the number of distinct observations for this obs type.
# if ``$obsType`` is not specified, returns the whole hash: ``$res->{obsType} = nb``
#
#/twdoc
sub getNbObsDistinct {
    my $self = shift;
    my $obsType = shift;

    $self->{logger}->debug("obtaining nb distinct obs for '".$self->{filename}."', obsType = ".(defined($obsType)?$obsType:"undef (all)")) if ($self->{logger});
    if (defined($obsType)) {
	$self->populate($obsType) if (!defined($self->{observs}->{$obsType}));
	confessLog($self->{logger}, "Error: invalid observation type '$obsType'; no such type found in the collection.") if (!defined($self->{observs}->{$obsType}));
	return $self->{nbObsDistinct}->{$obsType};
    } else {
	$self->populate() if (!defined($self->{observs}));
	return $self->{nbObsDistinct};
    }
}


#twdoc getNbObsDistinct($self, $obsType)
#
# returns the total number of observations for this obs type.
# if ``$obsType`` is not specified, returns the whole hash: ``$res->{obsType} = nb``
#
#/twdoc
sub getNbObsTotal {
    my $self = shift;
    my $obsType = shift;

    $self->{logger}->debug("obtaining total nb obs for '".$self->{filename}."', obsType = ".(defined($obsType)?$obsType:"undef (all)")) if ($self->{logger});
    if (defined($obsType)) {
	confessLog($self->{logger}, "Error: invalid observation type '$obsType'; no such type found in the collection.") if (!defined($self->{observs}->{$obsType}));
	$self->populate($obsType) if (!defined($self->{observs}->{$obsType}));
	return $self->{nbObsTotal}->{$obsType};
    } else {
	$self->populate() if (!defined($self->{observs}));
	return $self->{nbObsTotal};
    }
}


#twdoc readCountFile($self, $obsType)
#
# Reads the count file for ``$obsType`` and stores the data in ``$self``.
#
#/twdoc
sub readCountFile {
    my $self = shift;
    my $obsType = shift;

    my $prefix = $self->{filename};
    my $f = $self->getCountFileName($obsType);
    $self->{logger}->debug("obs type $obsType: reading count file '$f'") if ($self->{logger});
    my $a = readTSVFileLinesAsArray("$f.total", 2, $self->{logger});
    $self->{nbObsDistinct}->{$obsType} = $a->[0]->[0];
    $self->{nbObsTotal}->{$obsType} = $a->[0]->[1];
    $self->{observs}->{$obsType} = readTSVFileLinesAsHash($f, $self->{logger});
    $self->{logger}->debug("obs type $obsType: read ".$self->{nbObsTotal}->{$obsType}." observations") if ($self->{logger});
#	$self->{logger}->trace("obs type $obsType: ".scalar(keys %{$self->{observs}->{$obsType}})." observations in hash") if ($self->{logger});
}


#twdoc readCountFiles($self)
#
# Reads the count file for all the obs types and stores the data in ``$self``.
#
#/twdoc
sub readCountFiles {
    my $self = shift;

    $self->{logger}->debug("reading from all count files...") if ($self->{logger});
    foreach my $obsType (@{$self->{obsTypesList}}) {
	$self->readCountFile($obsType);
    }

}



#twdoc writeCountFiles($self, ?$columnObsType)
#
# writes ``<prefix>.observations/<obs type>.count`` and ``<prefix>.observations/<obs type>.count.total`` for every obs type.
# called from populate if useCountFiles=1; otherwise, must be used after calling ``getObservations()``
#
# * ``$columnObsType``: if true,  prints the obs type first on each line if defined.
#
#/twdoc
sub writeCountFiles {
    my $self = shift;
    my $columnObsType = shift; # optional

    my $prefix = $self->{filename};
    $self->{logger}->debug("Writing count files to '$prefix.observations/<obsType>.count'") if ($self->{logger});
    foreach my $obsType (@{$self->{obsTypesList}}) {
	my $f = $self->getCountFileName($obsType);
	$self->{logger}->debug("Writing count file: '$f'") if ($self->{logger});
	my $fh;
	open($fh, ">:encoding(utf-8)", $f) or confessLog($self->{logger}, "Cannot open file '$f' for writing");
	my $observs = $self->{observs}->{$obsType};
	$self->{logger}->debug("Writing observations for obs type '$obsType'") if ($self->{logger});
	while (my ($key, $nb) = each %$observs) {
	    print $fh "$obsType\t" if ($columnObsType);
	    printf $fh "%s\t%d\n", $key, $nb ;
	}
	close($fh);
	$f = "$f.total";
	open($fh, ">:encoding(utf-8)", $f) or confessLog($self->{logger}, "Cannot open file '$f' for writing");
	printf $fh "%d\t%d\n", $self->{nbObsDistinct}->{$obsType}, $self->{nbObsTotal}->{$obsType};
	close($fh);
    }
}



#twdoc readSourceDoc($self)
#
# Reads observations from the source document and stores the data in the object.
#
#/twdoc
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
