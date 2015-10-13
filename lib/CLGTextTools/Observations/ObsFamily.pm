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


sub getNbDistinctNGrams {
    my $self = shift;
    my $obsType = shift;
    return $self->{nbDistinctNGrams}->{$obsType};
}

sub getNbTotalNGrams {
    my $self = shift;
    my $obsType = shift;
    return $self->{nbTotalNGrams}->{$obsType};
}


sub getObservations {
    my $self = shift;
    my $obsType = shift;
    return $self->{observs}->{$obsType};
}


sub filterMinFreq {
    my $self = shift;
    my $obsType = shift;
    my $minFreq = shift;

    $self->{logger}->trace("Obs type '$obsType': filtering out ngrams with freq<$minFreq") if ($self->{logger});
    my $observs = $self->{observs}->{$obsType};
    my $nbRemoved = 0;
    while (my ($ngram, $freq) = each(%$observs)) {
	if ($freq < $minFreq) {
	    delete $observs->{$ngram};
	    $nbRemoved++;
	}
    }
    $self->{logger}->debug("Obs type '$obsType': removed $nbRemoved ngrams with freq<$minFreq from observations") if ($self->{logger});

}


sub convertToRelativeFreq {
    my $self = shift;
    my $obsType = shift;

    $self->{logger}->debug("Obs type '$obsType': converting to relative frequencies") if ($self->{logger});
    my $observs = $self->{observs}->{$obsType};
    my $total = $self->{nbTotalNGrams}->{$obsType};
    foreach my $ngram (keys %$observs) {
	$observs->{$ngram} /= $total;
    }
}


1;
