package Text::TextAnalytics::Tokenizer::Tokenizer;

use strict;
use warnings;
use Carp;

use base 'Exporter';
our @EXPORT_OK = qw/$defaultFrontierChar/;

our $VERSION = $Text::TextAnalytics::VERSION;



=head1 NAME

Text::TextAnalytics::Tokenizer::Tokenizer - abstract class for tokenizer objects


=cut

our $defaultFrontierChar = "#";


=head1 DESCRIPTION


=head2 new($class, $parameters)

creates a new Tokenizer object.
should be called by subclasses constructors (initializes logger).

=cut

sub new {
	my ($class, $params) = @_;
	my $self;
	foreach my $opt (keys %$params) {
		$self->{$opt} = $params->{$opt};
	}
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__);
	bless($self, $class);
	return $self; 	
}


=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut



=head2 tokenize($string)

returns a ref to the list of tokens OR a string

=cut


=head2 returnsList()

returns a boolean indicating whether the 'tokenize' method returns a list ref or a string

=cut


=head2 sub tokenizeWithFrontiers($string, $n, $frontierChar)

returns the tokenized string with 'frontiers' added, e.g. if n=2 (ab, bc, cd) becomes (#a, ab, bc, cd, d#).
if $frontierChar is defined it is used as the frontier character (otherwise $defaultFrontierChar is used)
no frontiers added if n < 2.

=cut

sub tokenizeWithFrontiers {
	my ($self, $string, $n, $frontierChar) = @_;
	my $tokens = $self->tokenize($string);
	$frontierChar = $defaultFrontierChar if (!defined($frontierChar));
	if ($n > 1) { # no frontiers needed otherwise
		$self->{logger}->debug("Adding 'frontiers' before and after the sequence of tokens");
		if ($self->returnsList()) {
			my @frontier = ($frontierChar) x ($n-1);
			my @tokens = (@frontier, @$tokens, @frontier);
			$tokens = \@tokens;
		} else {
			my $frontier = $defaultFrontierChar x ($n-1);
			$tokens = $frontier.$tokens.$frontier;
		}
	}
	return $tokens;
}

1;
