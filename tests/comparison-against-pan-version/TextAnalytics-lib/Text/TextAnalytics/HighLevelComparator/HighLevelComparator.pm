package Text::TextAnalytics::HighLevelComparator::HighLevelComparator;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics qw/$prefixModuleMeasure $prefixModuleTokenizer $prefixModuleNGrams $prefixModuleSegmentReader $prefixModuleScoresConsumer
		genericObjectBuilder parseObjectDescription/;
our $VERSION = $Text::TextAnalytics::VERSION;



=head1 NAME

Text::TextAnalytics::HighLevelComparator::HighLevelComparator - Abstract class for high level text comparison

=cut

# class variables describing the behaviour ("parameters") (see getParametersString)
my @parametersVars = (
					   "probeNGramsDescr", 
					   "refNGramsDescr", 
					   "measureDescr",
					   "tokenizerDescr" # Note: scoresConsumersDescr can not be printed this way because it is an array
					  );


=head1 METHODS

=head2 new($class, $parameters)

creates a new HighLevelComparator object. 
must be called by subclasses constructors. $parameters is a hash ref which must include:

=over 2

=item * measureDescr or measure: Measure object text description or actual object

=item * tokenizerDescr or tokenizer: Tokenizer object text description or actual object

=item * probeNGramsDescr or probeNGramsClassName/refNGramsParams: probe NGrams object text description or data (as parsed)

=item * refNGramsDescr or refNGramsClassName/refNGramsParams: ref NGrams object text description or data (as parsed)

=item * scoresConsumersDescr or scoresConsumers: an array of ScoresConsumer object(s) text description or actual object(s). can be empty but then a warning is emitted.

=back

=cut

sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__); 
	$self->{logger}->debug("Initializing");
	foreach my $opt (keys %$params) {
		$self->{$opt} = $params->{$opt};
#		print STDERR "debug1: $opt=".$self->{$opt}."\n";
	}

	# mandatory parameters:	
	$self->{logger}->logconfess("measure or measureDescr must be defined.") if (!defined($self->{measure}) && !defined($self->{measureDescr}));
	$self->{measure} = genericObjectBuilder(parseObjectDescription($self->{measureDescr}),$prefixModuleMeasure) if (!defined ($self->{measure}));

	$self->{logger}->logconfess("tokenizer or tokenizerDescr must be defined.") if (!defined($self->{tokenizer}) && !defined($self->{tokenizerDescr}));
	$self->{tokenizer} = genericObjectBuilder(parseObjectDescription($self->{tokenizerDescr}),$prefixModuleTokenizer) if (!defined($self->{tokenizer}));

	my $ordered = $self->{measure}->requiresOrderedNGrams();	
	my $unique = $self->{measure}->requiresUniqueNGrams();	
	my $probeDummyNGrams = checkNGramsObject($self, "probe", ref($ordered)?$ordered->[1]:$ordered, ref($unique)?$unique->[1]:$unique);
	my $size1 = _findMaxLengthNGrams($probeDummyNGrams->getN()); # Not very good TODO
	my $refDummyNGrams = checkNGramsObject($self, "ref", ref($ordered)?$ordered->[0]:$ordered, ref($unique)?$unique->[0]:$unique);
	my $size2 = _findMaxLengthNGrams($refDummyNGrams->getN()); # Not very good TODO
	$self->{sizeFrontiersTokens} = ($size2 > $size1)?$size2-1:$size1-1;
	$self->{logger}->logconfess("Invalid NGrams object(s) for measure ".$self->{measure}->getName()) if (!$self->{measure}->checkNGramsObjects($refDummyNGrams, $probeDummyNGrams));
	
	
	if (!defined($self->{scoresConsumers})) {
		$self->{logger}->logconfess("scoresConsumersDescr or scoresConsumers must be defined.") if (!defined($self->{scoresConsumersDescr}));
		$self->{scoresConsumers} = [];
		for (my $i=scalar(@{$self->{scoresConsumersDescr}})-1; $i >=0 ; $i--) {
#			print STDERR "DEBUG $i: ".$self->{scoresConsumersDescr}->[$i]."\n";
			my ($consumerClassname, $consumerParams) = parseObjectDescription($self->{scoresConsumersDescr}->[$i]);
			$consumerParams->{hlComparator} = $self;
			$consumerParams->{nextConsumer} = ($i==scalar(@{$self->{scoresConsumersDescr}})-1)?undef:$self->{scoresConsumers}->[$i+1]; 
			$self->{scoresConsumers}->[$i] = genericObjectBuilder($consumerClassname, $consumerParams, $prefixModuleScoresConsumer);
		}
	}
	


	bless($self, $class);
	return $self; 
}


sub _findMaxLengthNGrams {
	my ($size) = @_;
	if ($size =~ m/,/) { # multilevel ngram # #TODO dirty!
		my $max = 0;
		foreach my $s (split(",", $size)) {
			if ($s =~ m/\d+/) {
				$max = $s if ($s > $max);
			} else {
				$max = length($s) if (length($s) > $max);
			}
		} 
		$size = $max;
	}
	return $size;
}


sub checkNGramsObject {
	my ($self, $probeOrRef, $requiresOrdered, $requiresUnique) = @_;
	$self->{logger}->logconfess($probeOrRef."NGramsClassName or ".$probeOrRef."NGramsDescr must be defined.") if (!defined($self->{$probeOrRef."NGramsClassName"}) && !defined($self->{$probeOrRef."NGramsDescr"}));
	($self->{$probeOrRef."NGramsClassName"},$self->{$probeOrRef."NGramsParams"}) = parseObjectDescription($self->{$probeOrRef."NGramsDescr"}) if (!defined($self->{$probeOrRef."NGramsClassName"})); # in case it has been set directly (no string descrition)
	$self->{$probeOrRef."NGramsParams"}->{n} = 1 if (!defined($self->{$probeOrRef."NGramsParams"}->{n}));
	# test if ngrams and measure objects are compatible

	# test if tokenizer and ngrams objects are compatible
	my $dummyNGrams = genericObjectBuilder($self->{$probeOrRef."NGramsClassName"},$self->{$probeOrRef."NGramsParams"}, $prefixModuleNGrams);
	if (($self->{tokenizer}->returnsList() && $dummyNGrams->tokensAreCharacters()) || (!$self->{tokenizer}->returnsList() && !$dummyNGrams->tokensAreCharacters())) {
		$self->{logger}->logconfess("Incompatible Tokenizer and NGrams objects: one uses lists, the other uses strings.");
	}

	$self->{logger}->logconfess("Incompatible $probeOrRef NGrams and Measure objects: either NGrams are ordered and Measure requires unordered ngrams or the converse.") if ($dummyNGrams->ngramsAreOrdered() != $requiresOrdered); 
	$self->{logger}->logconfess("Incompatible $probeOrRef NGrams and Measure objects: either NGrams are unique and Measure requires non unique ngrams or the converse.") if ($dummyNGrams->ngramsAreUnique() != $requiresUnique);

	return $dummyNGrams;
}

=head2 initializeConsumers($parameters)

must be called before sending scores

=cut

sub initializeConsumers {
	my ($self, $parameters) = @_;
	
	$self->{scoresConsumers}->[0]->initialize($parameters);
}

=head2 finalizeConsumers($parameters)

must be called after sending all scores

=cut

sub finalizeConsumers {
	my ($self, $parameters) = @_;
	
	$self->{scoresConsumers}->[0]->finalize($parameters);
}



=head2 sendScoresToConsumers($score, $probeId, $refId)

transmits a score to the registered Consumer objects. $refId does not have to be defined if returnsScoresForSegmentPairs() is false (and must be defined otherwise).

=cut

sub sendScoresToConsumers {
	
	my ($self, $score, $probeId, $refId) = @_;
	
	$self->{logger}->debug("sending $probeId [refID] $score");
	my $segmentPair = $self->returnsScoresForSegmentPairs();
	if ($segmentPair) {
		$self->{scoresConsumers}->[0]->receiveScore($probeId, $refId, $score);
	} else {
		$self->{scoresConsumers}->[0]->receiveScore($probeId, $score);
	}
}


=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars,$prefix);
	$str .= $prefix."Measure parameters:\n".$self->{measure}->getParametersString($prefix."  ");
	$str .= $prefix."Tokenizer parameters:\n".$self->{tokenizer}->getParametersString($prefix."  ");
	my $dummyNGrams = genericObjectBuilder($self->{probeNGramsClassName},$self->{probeNGramsParams},$prefixModuleNGrams);
	$str .= $prefix."Probe NGrams parameters:\n".$dummyNGrams->getParametersString($prefix."  ");
	$dummyNGrams = genericObjectBuilder($self->{refNGramsClassName},$self->{refNGramsParams},$prefixModuleNGrams);
	$str .= $prefix."Reference NGrams parameters:\n".$dummyNGrams->getParametersString($prefix."  ");
	for(my $i=0; $i < scalar(@{$self->{scoresConsumers}});$i++) {
		$str .= $prefix."ScoresConsumer $i parameters:\n";
		$str .= $self->{scoresConsumers}->[$i]->getParametersString($prefix."  ");
	}
	return $str;
}


=head2 compare($refReader, $probeReader)

probeReader, refReader: SegmentReader objects for the probe/ref data

=cut




=head2 usesSingleReferenceData()

returns true if the data used as reference is expected to be provided as a single object (contrary to an array of objects, one for every segment).

=cut


=head2 returnsScoresForSegmentPairs()

returns true if the resulting scores are for pairs, i.e. probe+ref+score (contrary to probe+score)

=cut


=head2 getMeasure()

=cut

sub getMeasure {
	my $self = shift;
	return $self->{measure};
}


1;
