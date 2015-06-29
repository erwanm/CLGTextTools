package CLGTextTools::ObsCollection;

# EM June 2015
# 
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging;
use CLGTextTools::Observations::WordObsFamily;
use Data::Dumper::Simple;

use base 'Exporter';
our @EXPORT_OK = qw//;

our $decimalDigits = 10;


#
# $params:
# - logging
# - obsTypes (list)
# - wordTokenization = 1 by default; set to 0 if the text is already tokenized (with spaces); applies only to WordFamily observations (POSFamily uses pre-tokenized input, one token by line)
#
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	$self->{wordTokenization} = 1 unless (defined($params->{wordTokenization}) && ($params->{wordTokenization} == 0));
	$self->{families} = {};
	$self->{mapObsTypeToFamily} = {};
	bless($self, $class);
	if (defined($params->{obsTypes})) {
	    foreach my $obsType (@{$params->{obsTypes}}) {
		$self->addObsType($obsType);
	    }
	}
	$self->{logger}->trace("initiallized new object: ".Dumper($self)) if ($self->{logger});
	return $self; 	
}


sub addObsType {
    my $self= shift;
    my $obsType = shift;

    my ($family) = ($obsType =~ m/^([^.]+)\./);
    if (!defined($self->{families}->{$family})) {
	my $p = {logging => defined($self->{logger}), wordTokenization => $self->{wordTokenization} };
	if ($family eq "WORD") {
	    $self->{families}->{$family} = CLGTextTools::Observations::WordObsFamily->new($p);
	} elsif ($family eq "CHAR") {
	    $self->{families}->{$family} = CLGTextTools::Observations::CharObsFamily->new($p);
	} elsif ($family eq "POS") {
	    $self->{families}->{$family} = CLGTextTools::Observations::POSObsFamily->new($p);
	} elsif ($family eq "TTR") {
	    $self->{families}->{$family} = CLGTextTools::Observations::TTRObsFamily->new($p);
	} elsif ($family eq "LENGTH") {
	    $self->{families}->{$family} = CLGTextTools::Observations::LengthObsFamily->new($p);
	} elsif ($family eq "MORPH") {
	    $self->{families}->{$family} = CLGTextTools::Observations::MorphObsFamily->new($p);
	} elsif ($family eq "STOP") {
	    $self->{families}->{$family} = CLGTextTools::Observations::StopObsFamily->new($p);
	}
    }
    $self->{mapObsTypeToFamily}->{$obsType} = $family;
    $self->{families}->{$family}->addObsType($obsType);
}


sub addText {
    my $self = shift;
    my $text = shift;

    foreach my $family (keys ($self->{families})) {
	$self->{families}->{$family}->addText($text);
    }
}


sub getNbNGrams {
    my $self = shift;
    my $obsType = shift;
    my $family = $self->{mapObsTypeToFamily}->{$obsType};
    return $self->{families}->{$family}->getNbNGrams($obsType);
}


sub getObservations {
    my $self = shift;
    my $obsType = shift;
    my $family = $self->{mapObsTypeToFamily}->{$obsType};
    return $self->{families}->{$family}->getObservations($obsType);
}

#
# writes <prefix>.<obs>.count and <prefix>.<obs>.total for every obs
# type <obs> in $obstypesList if supplied, or every obs type in the
# objet if not (might include more types in this case, due to
# dependencies).
#
sub writeCountFiles {
    my $self = shift;
    my $prefix = shift;
    my $obsTypesList = shift; # optional

    if (!defined($obsTypesList)) {
	my @obsTypesList = (keys %{$self->{mapObsTypeToFamily}}) ;
	$obsTypesList = \@obsTypesList;
    }
    foreach my $obsType (@$obsTypesList) {
	my $f = "$prefix.$obsType.count";
	my $fh;
	open($fh, ">:encoding(utf-8)", $f) or logConfess("Cannot open file '$f' for writing");
	my ($uniqueNGrams, $totalNGrams) = $self->writeObsTypeCount($fh, $obsType);
	close($fh);
	$f = "$prefix.total";
	open($fh, ">:encoding(utf-8)", $f) or logConfess("Cannot open file '$f' for writing");
	printf $fh "%d\t%d\n", $uniqueNGrams, $totalNGrams;
	close($fh);
    }
}


sub writeObsTypeCount {
    my $self = shift;
    my $fh = shift;
    my $obsType = shift;
    my $columnObsType = shift; # optional: if not undef or 0, adds first column with obs type id

    my $family = $self->{mapObsTypeToFamily}->{$obsType};
    my $observs = $self->{families}->{$family}->getObservations($obsType);
    my $total = $self->{families}->{$family}->getNbNGrams($obsType);
#    while (my ($key, $nb) = each %$observs) {
    foreach my $key (sort keys %$observs) {
	my $nb = $observs->{$key};
	print $fh "%\t" if ($columnObsType);
	printf $fh "%s\t%d\t%.${decimalDigits}f\n", $key, $nb, ($nb/$total) ;
    }
    return (scalar(keys %$observs), $total );
}




1;
