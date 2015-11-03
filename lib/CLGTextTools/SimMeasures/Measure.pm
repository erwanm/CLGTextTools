package CLGTextTools::SimMeasures::Measure;

# EM Oct 2015
# 
#


use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;


#use base 'Exporter';
#our @EXPORT_OK = qw//;



#
# $params:
# - logging
#
sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__) if ($params->{logging});
	bless($self, $class);
	return $self; 	
}



#
# input: two hash refs, $doc->{ obs } = freq
#
sub compute {
#    my ($doc1, $doc2) = @_;
    confessLog($self->{logger}, "bug: calling an abstract method");
}


1;
