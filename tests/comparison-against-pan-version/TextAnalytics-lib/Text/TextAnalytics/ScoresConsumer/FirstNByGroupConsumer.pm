package Text::TextAnalytics::ScoresConsumer::FirstNByGroupConsumer;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::ScoresConsumer::ScoresConsumer;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::ScoresConsumer::ScoresConsumer/;

=head1 NAME

Text::TextAnalytics::ScoresConsumer::FirstNByGroupConsumer - keeps only the N first scores for each group

=head1 DESCRIPTION

This consumer groups together series of data and sends only the N first received for each group.

=cut

my %defaultOptions = ( 
						"groupByArgsNos" => "0",
  	  				    "noUnderflowWarning" => 0,
						"internalSeparator" => "\t",
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
our @parametersVars = (
						"nbValues",
						"groupByArgsNos",
  	  				    "noUnderflowWarning"
					  );



=head2 new($class, $params)

$params is a hash ref which must define:

=over 2

=item * nbValues: the number of values to send for each group.

=back
 
 and optionaly defines the following parameters: 
=over 2

=item * groupByArgsNos: the args nos by which series of data should be
grouped, separated by commas. For example if groupByArgsNos="2,4" then
all lines with identical values in columns 2 and 4 are grouped together,
and the result for each group is <val arg2> <val arg4> <average value>.
If no arg no is provided (empty string), then the "group" is the whole data. 
Default: 0 (first arg).

=item * internalSeparator: character used internally to separate data in a hash,
so this character must not appear in the actual data. Default: tabulation.

=item * noUnderflowWarning: 0 by default, which means that a warning is issued if less than nbValues are received. This does not happen if this parameter is set to true.

=back

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $param (keys %defaultOptions) {
		$self->{$param} = $defaultOptions{$param} if (!defined($self->{$param}));
#		print STDERR " debug: param $param=$self->{$param}\n";
	}
	@{$self->{groupsNos}} = split(/,/, $self->{groupByArgsNos});
	$self->{logger}->logconfess("Parameter nbValues must be defined.") if(!defined($self->{nbValues}));
	$self->{nb} = undef;
	return $self; 	
}



=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = $self->SUPER::getParametersString($prefix);
	$str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars,$prefix, 1);
	return $str;
}




=head 2 receiveScore(@data)

see superclass 

=cut

sub receiveScore {
	my $self = shift;
	my @args = @_;
	my @group = map {$args[$_]} @{$self->{groupsNos}};
	$self->{logger}->debug("groupsNo=".join(";",@{$self->{groupsNos}})." ; group=".join(";",@group)." ; args=".join(";",@args)) if ($self->{logger}->is_debug());
	my $groupId = join($self->{internalSeparator}, @group);
	$self->{nb}->{$groupId}++;
	if ($self->{nb}->{$groupId} <= $self->{nbValues}) {
		$self->{nextConsumer}->receiveScore(@args) if (defined($self->{nextConsumer}));
	}
}



=head2 finalize($footer)

if defined, writes the footer to the file. 

=cut

sub finalize {
	my ($self, $footer) = @_;
	if ($self->{noUnderflowWarning}) {
		if (defined($self->{nb})) {
			my $underflow=0;
			foreach my $id (keys %{$self->{nb}}) {
				$underflow++ if ($self->{nb}->{$id} < $self->{nbValues});
			}
			$self->{logger}->logwarn("$underflow groups contained less than ".$self->{nbValues}." values.") if ($underflow>0); 
		} else {
			$self->{logger}->logwarn("No value received (receiveScore has not been called at all), nothing sent to the next consumer (if any)");
		}
	}
	$self->SUPER::finalize($footer);
}




1;


