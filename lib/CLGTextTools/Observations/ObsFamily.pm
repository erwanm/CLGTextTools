package CLGTextTools::Observations::ObsFamily;

# EM June 2015
# 
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging;

#use base 'Exporter';
#our @EXPORT_OK = qw//;



#
# $params:
# - logging
# - obsTypes (list)
#
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
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
    $self->{logger}->logconfess("__PACKAGE__: cannot execute abstract method 'addText'.");
}


sub getNbNGrams {
    my $self = shift;
    my $obsType = shift;
    return $self->{nbNGrams}->{$obsType};
}


sub getObservations {
    my $self = shift;
    my $obsType = shift;
    return $self->{observs}->{$obsType};
}




1;
