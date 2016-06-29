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
# $params:
# - logging
# - obsTypes (list)
#
#/twdoc
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


#
# addText($text)
#
sub addText {
    my $self = shift;
    confessLog($self->{logger}, "__PACKAGE__: cannot execute abstract method 'addText'.");
}


sub getNbDistinctNGrams {
    my $self = shift;
    my $obsType = shift;
    confessLog($self->{logger}, "No obs type '$obsType' or obs family not populated yet") if (!defined($self->{nbDistinctNGrams}->{$obsType}));
    return $self->{nbDistinctNGrams}->{$obsType};
}

sub getNbTotalNGrams {
    my $self = shift;
    my $obsType = shift;
    confessLog($self->{logger}, "No obs type '$obsType' or obs family not populated yet") if (!defined($self->{nbTotalNGrams}->{$obsType}));
    return $self->{nbTotalNGrams}->{$obsType};
}


sub getObservations {
    my $self = shift;
    my $obsType = shift;
    confessLog($self->{logger}, "No obs type '$obsType' or obs family not populated yet") if (!defined($self->{observs}->{$obsType}));
    return $self->{observs}->{$obsType};
}



1;
