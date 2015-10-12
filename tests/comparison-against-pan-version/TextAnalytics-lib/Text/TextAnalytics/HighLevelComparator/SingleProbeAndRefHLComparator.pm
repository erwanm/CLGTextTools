package Text::TextAnalytics::HighLevelComparator::SingleProbeAndRefHLComparator;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::HighLevelComparator::StdHLComparator;
use  Text::TextAnalytics::Tokenizer::Tokenizer qw/$defaultFrontierChar/;

our @ISA = qw/Text::TextAnalytics::HighLevelComparator::StdHLComparator/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::HighLevelComparator::SingleProbeAndRefHLComparator -  class for high level text comparison (one single comparison)



=cut





my %defaultOptions = (  
					   "addTokensFrontiers" => 0,
					   "minTokens" => 0,
					   "minNGrams" => 0,
					   "verbose" => 1, 
					   "information" => ""
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
my @parametersVars = (
					   "addTokensFrontiers", 
					   "minTokens", 
   					   "minNGrams",
					   "verbose", 
					  );

=head1 DESCRIPTION

ISA = Text::TextAnalytics::HighLevelComparator::StdHLComparator

=head2 new($class, $params)

$params is an hash ref which optionally defines the following parameters: 

=over 2

=item *  addTokensFrontiers: boolean. adds "frontiers" at the beginning and end of every segment, e.g. if n=2 (ab, bc, cd) becomes (#a, ab, bc, cd, d#). 

=item *  minTokens: integer, minimum number of tokens for the segment to be taken into account

=item *  minNGrams: integer, minimum number of ngrams - after preprocessing - for the segment to be taken into account

=item * verbose: boolean. if 0, nothing is printed to stdout.

=item * information: string

=back

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	return $self; 	
}


=head2 getParametersString($prefix)

see parent documentation

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
    my $str = $self->SUPER::getParametersString($prefix);
	$str .= $prefix."Reference reader parameters:\n".$self->{refReader}->getParametersString($prefix."  ");
	$str .= $prefix."Probe reader parameters:\n".$self->{probeReader}->getParametersString($prefix."  ");
    $str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix,1);
	return $str;
}


=head2 compare($refReader, $probeReader)

see parent documentation

=cut

sub compare {
	my $self = shift;
	my $refReaderParam = shift;
	my $probeReaderParam = shift;
	$self->{logger}->logconfess("Error: probe and/or reference reader parameters must be defined.") if (!defined($probeReaderParam));
	$self->{probeReader} = ref($probeReaderParam)?$probeReaderParam:genericObjectBuilder(parseObjectDescription($probeReaderParam), $Text::TextAnalytics::prefixModuleSegmentReader);
	$self->{refReader} = ref($refReaderParam)?$refReaderParam:genericObjectBuilder(parseObjectDescription($refReaderParam), $Text::TextAnalytics::prefixModuleSegmentReader);

	my $startDate = localtime();
	my $startTimeS = time();
	$self->{logger}->logconfess("probeReader and refReader must be defined.") if (!defined($self->{probeReader}) || !defined($self->{refReader}));
	my $info = "Started $startDate (v. $VERSION)\n";
	print $info if ($self->{verbose});
	$self->{information} .= "# $info";
	$info = "Reading reference corpus...";
	print "$info\n" if ($self->{verbose});
	$self->{logger}->info("$info");	
	($self->{refDataNGrams}, $_) = $self->loadSegmentsAsNGrams( $self->{refReader}, 1, undef, "ref" );
	print "\n" if ($self->{verbose});
	$self->{probeNGramsParams}->{shared} = $self->{refDataNGrams};
	if ($self->{refDataNGrams}->ngramsAreUnique()) {
		$info = "In reference data: ".$self->{refDataNGrams}->getNbDistinctNGrams()." distinct ngrams, accounting for a total of ".$self->{refDataNGrams}->getTotalCount()." ngrams.";
		print "$info\n" if ($self->{verbose});
		$self->{logger}->info("$info");	
		$self->{information} .= "# $info\n";
	}
	$info = "Reading probe corpus...";
	print "$info\n" if ($self->{verbose});
	$self->{logger}->info("$info");	
	($self->{probeDataNGrams}, $_) = $self->loadSegmentsAsNGrams( $self->{probeReader}, 1, undef, "probe");
	print "\n" if ($self->{verbose});
	if ($self->{refDataNGrams}->ngramsAreUnique()) {
		$info = "In probe data: ".$self->{probeDataNGrams}->getNbDistinctNGrams()." distinct ngrams, accounting for a total of ".$self->{probeDataNGrams}->getTotalCount()." ngrams.";
		print "$info\n" if ($self->{verbose});
		$self->{logger}->info("$info");	
		$self->{information} .= "# $info\n";
	}
	$self->{information} .= $self->getParametersString("# ");
	$self->initializeConsumers($self->{information});
	$info = "Comparing ngrams using ".$self->{measure}->getName()."...";
	print "$info\n"  if ($self->{verbose});
	$self->{logger}->info($info);
	my $score = $self->{measure}->score("P".$self->{probeReader}->getId(), $self->{probeDataNGrams}, "R".$self->{refReader}->getId(), $self->{refDataNGrams});
	$self->sendScoresToConsumers($score, $self->{probeReader}->getId(), $self->{refReader}->getId());
	my $endDate = localtime();
	my $endTimeS = time();
	$self->{information} .= "# ended $endDate\n";
	$info  = sprintf("Time elapsed: %d seconds\n",($endTimeS-$startTimeS));
	print "$info"  if ($self->{verbose});
	$self->{information} .= "# $info";
	$self->finalizeConsumers($self->{information});
}








=head2 usesSingleReferenceData()

see parent documentation

=cut

sub usesSingleReferenceData {
	return 1;	
}



=head2 returnsScoresForSegmentPairs()

see parent documentation

=cut

sub returnsScoresForSegmentPairs {
	return 1;
}

1;
