package CLGTextTools::Observations::ObsFamily;

#twdoc
#
# Parent class for obs family classes.
#
# ---
# EM June 2015
# 
#/twdoc


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog/;

#use base 'Exporter';
#our @EXPORT_OK = qw//;


#twdoc new($class, $params, $subclass)
#
# 
# * ``$params``:
# ** logging
# ** obsTypes
# * ``$subclass``: used only to initialize the logger object with the right package id 
#/twdoc
# 
sub new {
	my ($class, $params, $subclass) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(defined($subclass)?$subclass:__PACKAGE__) if ($params->{logging});
	$self->{observs} = {};
	bless($self, $class);
	if (defined($params->{obsTypes})) {
	    foreach my $obsType (@{$params->{obsTypes}}) {
		$self->addObsType($obsType);
	    }
	}
	return $self; 	
}


#twdoc addObsType($self, $obsType)
#
# * ''Abstract''
#
# Adds an obs type to the current list of obs type (this must be done before populating the data).
#
#/twdoc
sub addObsType {
    my $self = shift;
    $self->{logger}->logconfess("__PACKAGE__: cannot execute abstract method 'addObsTypes'.");
}

# OBSOLETE, gave up on this.
#
# a subclass which requires some other obs types must return their ids in this method.
#
#sub requiresObsTypes {
#    my $self = shift;
#    $self->{logger}->logconfess("__PACKAGE__: cannot execute abstract method 'requiresObsTypes'.");
#}


#twdoc addText($self, $text)
#
# * ''Abstract''
#
# Adds the observations found in ``$text`` to the current sets of observations for every obs type in the family.
#
#/twdoc
sub addText {
    my $self = shift;
    confessLog($self->{logger}, "__PACKAGE__: cannot execute abstract method 'addText'.");
}

#twdoc getNbDistinctNGrams($self, $obsType)    
# 
# Returns the number of distinct observations (i.e. not counting multiple occurrences) for ``$obsType``. 
# 
#/twdoc
sub getNbDistinctNGrams {
    my $self = shift;
    my $obsType = shift;
    confessLog($self->{logger}, "No obs type '$obsType' or obs family not populated yet") if (!defined($self->{nbDistinctNGrams}->{$obsType}));
    return $self->{nbDistinctNGrams}->{$obsType};
}


#twdoc getNbTotalNGrams($self, $obsType)    
# 
# Returns the total number of observations (i.e. taking multiple occurrences into account) for ``$obsType``.
#
#/twdoc
sub getNbTotalNGrams {
    my $self = shift;
    my $obsType = shift;
    confessLog($self->{logger}, "No obs type '$obsType' or obs family not populated yet") if (!defined($self->{nbTotalNGrams}->{$obsType}));
    return $self->{nbTotalNGrams}->{$obsType};
}



#twdoc getObservations($self, $obsType)
#
# Returns the observations for ``$obsType`` as a hash ref ``h->{obs} = freq``
# (should be called only after the data has been populated/finalized)
#
#/twdoc
sub getObservations {
    my $self = shift;
    my $obsType = shift;
    confessLog($self->{logger}, "No obs type '$obsType' or obs family not populated yet") if (!defined($self->{observs}->{$obsType}));
    return $self->{observs}->{$obsType};
}



1;
