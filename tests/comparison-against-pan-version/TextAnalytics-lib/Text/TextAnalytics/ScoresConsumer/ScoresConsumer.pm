package Text::TextAnalytics::ScoresConsumer::ScoresConsumer;

use strict;
use warnings;
use Carp;

our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::ScoresConsumer::ScoresConsumer - abstract class for objects which receive "data" (ids, scores, ranks etc) and do something with them

=head1 DESCRIPTION

subclasses must override receiveScore, and can override initialize, finalize.

Principle: consumers are components which can be chained in a processing flow. A consumer receives input data through "receiveScore" and can optionally output
modified (or the same) data using another consumer's "receiveScore" method, which transmits the new data to the next consumer. Each data received simply consists in an array of arguments 
transmitted the usual way (with @_) to the method. It is meant to represent a line of data, e.g. <probe id> <ref id> <score>, but this interpretation depends
on the consumer itself.
To send the output of a consumer to the next consumer, set the parameter "nextConsumer".

Convention: argument counting in receiveScores starts at 0 (first argument after $self is $_[0])

=cut

our $defaultEncoding = "utf-8";

my %defaultOptions = ( 
					   "encoding" => $defaultEncoding,
					   "nextConsumer" => undef 
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
our @parametersVars = (
					   "encoding"
					  );



=head2 new($class, $params)

must be called by subclasses constructors.
$params is a hash ref which optionaly defines:
 
=over 2

=item * nextConsumer a consumer to which the scores should be sent (otherwise they are not transmitted and the consumer is the end of the chain)

=item * encoding: string

=back

defines $self->{logger}

=cut

sub new {
	my ($class, $params) = @_;
	my $self;
	%$self = %defaultOptions;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__); 
	foreach my $opt (keys %$params) {
		$self->{$opt} = $params->{$opt};
	}
	bless($self, $class);
	return $self; 	
}



=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix);
	return $str;
}


=head 2 receiveScore(@data)
=cut



=head2 initialize($header)

called  before sending any score. by default only calls nextConsumer->initialize(), if any.

=cut

sub initialize {
	my ($self, $header) = @_;
	$self->{nextConsumer}->initialize($header) if (defined($self->{nextConsumer}));
}

=head2 finalize($footer)

called when the process is finished (you can close files here for example, or compute anything which is not possible before receiving all scores).
by default only calls nextConsumer->finalize(), if any.

=cut

sub finalize {
	my ($self, $footer) = @_;
	$self->{nextConsumer}->finalize($footer) if (defined($self->{nextConsumer}));
}




1;


