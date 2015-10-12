package Text::TextAnalytics::HighLevelComparator::CountNGramsOnlyHLComparator;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::HighLevelComparator::StdHLComparator;
use  Text::TextAnalytics::Tokenizer::Tokenizer qw/$defaultFrontierChar/;
use Text::TextAnalytics qw/$prefixModuleMeasure $prefixModuleTokenizer $prefixModuleNGrams $prefixModuleSegmentReader $prefixModuleScoresConsumer
		genericObjectBuilder parseObjectDescription/;
use Text::TextAnalytics::ScoresConsumer::ScoresWriterConsumer;

our @ISA = qw/Text::TextAnalytics::HighLevelComparator::StdHLComparator/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::HighLevelComparator::CountNGramsOnlyHLComparator -  



=cut





my %defaultOptions = (  
					   "addTokensFrontiers" => 0,
					   "minTokens" => 0,
					   "minNGrams" => 0,
					   "verbose" => 1, 
					   "information" => "",
					   "printNGramKey" => 0,
					   "filename" => "count-ngrams.dat"
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
my @parametersVars = (
					   "addTokensFrontiers", 
					   "minTokens", 
   					   "minNGrams",
					   "verbose",
					   "printNGramKey",
					   "filename" 
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

=item * printNGramKey

=item * filename

=back

=cut

sub new {
	my ($class, $params) = @_;
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__); 
	foreach my $opt (keys %$params) {
		$self->{$opt} = $params->{$opt};
#		print STDERR "debug1: $opt=".$self->{$opt}."\n";
	}
	foreach my $opt (keys %defaultOptions) {
		$self->{$opt} = $defaultOptions{$opt} if (!defined($self->{$opt}));
	}
	$self->{logger}->logconfess("refNGramsClassName or refNGramsDescr must be defined.") if (!defined($self->{refNGramsClassName}) && !defined($self->{refNGramsDescr}));
	($self->{refNGramsClassName},$self->{refNGramsParams}) = parseObjectDescription($self->{refNGramsDescr}) if (!defined($self->{refNGramsClassName})); # in case it has been set directly (no string descrition)
	$self->{refNGramsParams}->{n} = 1 if (!defined($self->{refNGramsParams}->{n}));
	
	$self->{logger}->logconfess("tokenizer or tokenizerDescr must be defined.") if (!defined($self->{tokenizer}) && !defined($self->{tokenizerDescr}));
	$self->{tokenizer} = genericObjectBuilder(parseObjectDescription($self->{tokenizerDescr}),$prefixModuleTokenizer) if (!defined($self->{tokenizer}));

	# test if tokenizer and ngrams objects are compatible
	my $dummyNGrams = genericObjectBuilder($self->{refNGramsClassName},$self->{refNGramsParams}, $prefixModuleNGrams);
	if (($self->{tokenizer}->returnsList() && $dummyNGrams->tokensAreCharacters()) || (!$self->{tokenizer}->returnsList() && !$dummyNGrams->tokensAreCharacters())) {
		$self->{logger}->logconfess("Incompatible Tokenizer and NGrams objects: one uses lists, the other uses strings.");
	}
	
	$self->{scoresConsumers}->[0] = Text::TextAnalytics::ScoresConsumer::ScoresWriterConsumer->new({filename => $self->{filename}});

	bless($self, $class);
	return $self; 	
}


=head2 getParametersString($prefix)

see parent documentation

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
#    my $str = $self->SUPER::getParametersString($prefix);
    my $str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix,1);
	$str .= $prefix."Reader parameters:\n".$self->{reader}->getParametersString($prefix."  ");
	$str .= $prefix."Tokenizer parameters:\n".$self->{tokenizer}->getParametersString($prefix."  ");
	my $dummyNGrams = genericObjectBuilder($self->{refNGramsClassName},$self->{refNGramsParams},$prefixModuleNGrams);
	$str .= $prefix."NGrams parameters:\n".$dummyNGrams->getParametersString($prefix."  ");
	return $str;
}


=head2 compare($reader)


=cut

sub compare {
	my $self = shift;
	$self->{reader} = shift;
	my $startDate = localtime();
	my $startTimeS = time();
	$self->{logger}->logconfess("reader must be defined.") if (!defined($self->{reader}));
	my $info = "Started $startDate (v. $VERSION)\n";
	print $info if ($self->{verbose});
	$self->{information} .= "# $info";
	$info = "Reading reference corpus...";
	print "$info\n" if ($self->{verbose});
	$self->{logger}->info("$info");	
	my %nbSegmentsByNGram;
	($self->{dataNGrams}, $self->{nbSegments}) = $self->loadSegmentsAsNGrams( $self->{reader}, 1, \%nbSegmentsByNGram, "ref" );
	print "\n" if ($self->{verbose});
	if ($self->{dataNGrams}->ngramsAreUnique()) {
		$info = "In reference data: ".$self->{dataNGrams}->getNbDistinctNGrams()." distinct ngrams, accounting for a total of ".$self->{dataNGrams}->getTotalCount()." ngrams.";
		print "$info\n" if ($self->{verbose});
		$self->{logger}->info("$info");	
		$self->{information} .= "# $info\n";
	}
	$self->{information} .= $self->getParametersString("# ");
	$self->initializeConsumers($self->{information});

	$self->{scoresConsumers}->[0]->receiveScore($self->{dataNGrams}->getN(), $self->{dataNGrams}->getTotalCount(), $self->{nbSegments});
	foreach my $ngram (@{$self->{dataNGrams}->getNGramsListRef()}) {
		my $key = $self->{dataNGrams}->getKey($ngram);
		my $value = $self->{dataNGrams}->getValueFromKey($key);
		my $nbSegments = $nbSegmentsByNGram{$key};
		if ($self->{printNGramKey}) {
			$self->{scoresConsumers}->[0]->receiveScore($value, $nbSegments, $key, @$ngram);
		} else {
			$self->{scoresConsumers}->[0]->receiveScore($value, $nbSegments, @$ngram);
		}	
	}

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
