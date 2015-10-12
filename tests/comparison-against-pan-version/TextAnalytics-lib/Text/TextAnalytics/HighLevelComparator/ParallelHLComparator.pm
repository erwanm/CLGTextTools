package Text::TextAnalytics::HighLevelComparator::ParallelHLComparator;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::HighLevelComparator::StdHLComparator;
use Text::TextAnalytics qw/$prefixModuleMeasure $prefixModuleTokenizer $prefixModuleNGrams $prefixModuleSegmentReader genericObjectBuilder parseObjectDescription/;
use  Text::TextAnalytics::Tokenizer::Tokenizer qw/$defaultFrontierChar/;

our @ISA = qw/Text::TextAnalytics::HighLevelComparator::StdHLComparator/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::HighLevelComparator::ParallelHLComparator -  high level text parallel comparison

=cut





my %defaultOptions = (  
					   "outputAlsoRefId" => 1,
					   "addTokensFrontiers" => 0,
					   "minNGrams" => 0,
					   "verbose" => 1, 
					   "information" => ""
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
my @parametersVars = (
					   "outputAlsoRefId",
					   "addTokensFrontiers", 
					   "minNGrams", 
					   "verbose", 
					  );

=head1 DESCRIPTION

ISA = Text::TextAnalytics::HighLevelComparator::StdHLComparator

=head2 new($class, $params)

$params is an hash ref which optionally defines the following parameters: 

=over 2

=item * outputAlsoRefId: boolean, true by default. indicates whether to send both ids to the scores consumers, i.e. "<probe id> <ref id> <score>" (default) against "<probe id> <score>".

=item *  addTokensFrontiers: boolean. adds "frontiers" at the beginning and end of every segment, e.g. if n=2 (ab, bc, cd) becomes (#a, ab, bc, cd, d#). 

=item *  minTokens: integer, minimum number of tokens for the segment to be taken into account

=item * verbose: boolean. if 0, nothing is printed to stdout.

=item * information: string

=item * columnSeparator: string (usually one character)

=back

Warning: if scoresFileName and rankingFileName are undefined and storeScores is 0 there will be no output at all (the scores
are computed but not stored anywhere)

Remark: All values including NaN are written to the scores file, but NaN are not taken into
account in the ranking (so the latter can be smaller than the former)

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	if ($self->{measure}->requiresSegmentsCountByNGram()) {
		$self->{logger}->logconfess("Error: measure ".$self->{measure}->getName()." requires counting the number of segments for each ngram, which is not possible in this version of ".__PACKAGE__.".");
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
	$self->{information} .= $self->getParametersString("# ");
	$self->initializeConsumers($self->{information});
	$info = "Reading segments...";
	print "$info\n" if ($self->{verbose});
	$self->{logger}->info($info);	
	
	my @data;
	my @nbTokens = (0,0);
	my $nbSkipped = 0;
	my $globalNGrams = genericObjectBuilder($self->{refNGramsClassName}, $self->{refNGramsParams},$Text::TextAnalytics::prefixModuleNGrams); # used as a reference for shared index
    my $docCountOrUndef = $self->{measure}->requiresSegmentsCountByNGram()?{}:undef;
	while (defined($data[0] = $self->{probeReader}->next()) & defined($data[1] = $self->{refReader}->next())) {  # Remark: the single "&" is important because we want to check that both documents have the same number of segments
		my @tokens;
		my @ngrams;
		my $currNbRead = $self->{probeReader}->getNbAlreadyRead();
		my $currentId = $self->{probeReader}->getCurrentId();
		my $progress = $self->{probeReader}->getProgress();
		$progress = defined($progress)?sprintf("[%5.1f%%]",$progress*100):"";
		print "\rProcessing parallel segments no ".$currNbRead." ".(($currNbRead eq $currentId)?"":" (id $currentId)")." $progress ..." if ($self->{verbose});
		$self->{logger}->debug("Preprocessing probe segment no $currNbRead (id $currentId)") if ($self->{logger}->is_debug());
		$tokens[0] = $self->preprocessSegment($data[0], "probe");
		$self->{logger}->debug("Preprocessing reference segment no $currNbRead (id $currentId)") if ($self->{logger}->is_debug());
		$tokens[1] = $self->preprocessSegment($data[1], "ref");
		my @nbNGrams;
		for my $i (0,1) {
			my $probeOrRef = $i?"ref":"probe";
			$nbTokens[$i] += $self->{tokenizer}->returnsList()?scalar(@{$tokens[$i]}):length($tokens[$i]);
			$ngrams[$i] = genericObjectBuilder($self->{$probeOrRef."NGramsClassName"}, { shared => $globalNGrams, %{$self->{$probeOrRef."NGramsParams"}} }, $Text::TextAnalytics::prefixModuleNGrams); # NB: $globalNGrams is used as a dummy object to share index, actually it is always empty in this case
			$nbNGrams[$i] = $ngrams[$i]->addTokens($tokens[$i], $docCountOrUndef, $self->{minNGrams});
		}	
		$self->{logger}->debug("nbNGrams[0]=$nbNGrams[0] ; nbNGrams[1]=$nbNGrams[1]");
		if (($nbNGrams[0] > -1 ) && ($nbNGrams[1] > -1 )) {
			$self->{logger}->debug("Computing similarity for segments no $currNbRead (id $currentId)");		
			my $score = $self->{measure}->score("P".$self->{probeReader}->getCurrentId(), $ngrams[0], "R".$self->{refReader}->getCurrentId(), $ngrams[1]);
			$self->sendScoresToConsumers($score, $self->{probeReader}->getCurrentId(), $self->{outputAlsoRefId}?$self->{refReader}->getCurrentId():undef);
		} else {
			# TODO getTotalCount wrong for MultiLevelNGrams
			$self->{logger}->debug("Skipping segments no $currNbRead (id $currentId): not enough ngrams (probe: ".$ngrams[0]->getTotalCount()."; ref: ".$ngrams[1]->getTotalCount().")");		
			$nbSkipped++;
		} 
	}
	if ((!defined($data[0]) && defined($data[1])) || (defined($data[0]) && !defined($data[1]))) {
		$self->{logger}->logconfess("Warning: not the same number of segments in probe and ref data!");
	}
	
	
	my $nbSegmentsProcessed = $self->{probeReader}->getNbAlreadyRead()-$nbSkipped;
	$info = "End of process: read ".$self->{probeReader}->getNbAlreadyRead()." segments in parallel, processed $nbSegmentsProcessed segments and skipped $nbSkipped segments. $nbTokens[0] read in probe data, $nbTokens[1] read in ref data.";
	$self->{information} .= "# $info\n";
	$self->{logger}->info($info);
	print "\n$info\n"  if ($self->{verbose});
	my $endDate = localtime();
	my $endTimeS = time();
	$self->{information} .= "# ended $endDate\n";
	$info  = sprintf("Time elapsed: %d seconds\n",($endTimeS-$startTimeS));
	print "$info"  if ($self->{verbose});
	$self->{information} .= "# $info";
	$self->finalizeConsumers($self->{information});
}





#=head2 preprocessSegment($data)
#
#returns the tokens corresponding to the given string according to the preprocessing options provided,
#(as a list of tokens or a string). 
#
#=cut
#
#sub preprocessSegment {
#	my ($self, $data) = @_;
#	chomp($data);
#	$self->{logger}->trace("data read '$data'");
#	my $tokens = $self->{tokenizer}->tokenize($data);
#	if ($self->{addTokensFrontiers}) {
#		$self->{logger}->debug("Adding 'frontiers' before and after the sequence of tokens");
#		if ($self->{tokenizer}->returnsList()) {
#			my @frontier = ($defaultFrontierChar) x ($self->{nGramsParams}->{n}-1);
#			my @tokens = (@frontier, @$tokens, @frontier);
#			$tokens = \@tokens;
#		} else {
#			my $frontier = $defaultFrontierChar x ($self->{nGramsParams}->{n}-1);
#			$tokens = $frontier.$tokens.$frontier;
#		}
#	}
#	$self->{logger}->debug("tokens = ( ".($self->{tokenizer}->returnsList()?join(" ",@$tokens):$tokens)." )") if ($self->{logger}->is_debug());
#	return $tokens;
#}







=head2 usesSingleReferenceData()

returns 0

=cut

sub usesSingleReferenceData {
	my $self = shift;
	return 0;	
}



=head2 returnsScoresForSegmentPairs()

returns 1

=cut

sub returnsScoresForSegmentPairs {
	my $self = shift;
	return $self->{outputAlsoRefId};
}


1;
