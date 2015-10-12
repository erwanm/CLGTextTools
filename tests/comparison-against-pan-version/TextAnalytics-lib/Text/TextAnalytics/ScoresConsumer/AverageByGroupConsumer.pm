package Text::TextAnalytics::ScoresConsumer::AverageByGroupConsumer;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::ScoresConsumer::ScoresConsumer;
use Text::TextAnalytics;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::ScoresConsumer::ScoresConsumer/;

=head1 NAME

Text::TextAnalytics::ScoresConsumer::AverageByGroupConsumer - avg score (or rank) by group

=head1 DESCRIPTION

This consumer groups together series of data and sends the average for each such group.

=cut

my %defaultOptions = ( 
						"valueArgNo" => undef,
						"groupByArgsNos" => "0",
						"checkSameNumberByGroup" => 1,
						"expectedNumberByGroup" => undef,
						"consecutiveGroups" => 0,
  	  				    "noNaNWarning" => 0,
						"internalSeparator" => "\t",
						"downscaleRanks" => 0
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
our @parametersVars = (
						"valueArgNo",
						"groupByArgsNos",
						"checkSameNumberByGroup",
						"expectedNumberByGroup",
						"consecutiveGroups",
						"noNaNWarning",
						"downscaleRanks"
					  );



=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:
 
=over 2

=item * valueArgNo: arg no for the value to use for the average. If undefined,
then the last arg is used (this is the default).

=item * groupByArgsNos: the args nos by which series of data should be
grouped, separated by commas. For example if groupByArgsNos="2,4" then
all lines with identical values in columns 2 and 4 are grouped together,
and the result for each group is <val arg2> <val arg4> <average value>.
If no arg no is provided (empty string), then the "group" is the whole data 
and the global average will be the only output. Default: 0 (first arg).

=item * checkSameNumberByGroup: if true (default), a warning is emitted
if there is not the same number of elements in every group.

=item * expectedNumberByGroup: can be used for two reasons: check that
there is the same number (and this precise number) in every group, and
also to allow the consumer to send the data as soon as the number of values
is reached. Can also save memory (values are not kept in memory when
the group is completed).

=item * consecutiveGroups: set to true to allow the consumer to consider
that a group is finished as soon as a new one is started. Can also save memory
(values are not kept in memory when the group is completed).

=item * downscaleRanks: use only when averaging ranks values: divide the resulting 
average value by the number of segments by group, in order to obtain a relative
rank between 1 and N where N is the number of elements. An additional warning is 
emitted if the number of values by group is different. Default is 0.


=item * internalSeparator: character used internally to separate data in a hash,
so this character must not appear in the actual data. Default: tabulation.

=item * noNaNWarning: 0 by default, which means that a warning is issued if NaN values are found. This does not happen if this parameter is set to true.

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
	$self->{sum} = undef;
	$self->{nb} = undef;
	$self->{data} = undef;
	$self->{observedNbByGroup} = undef;
	$self->{nbNaN} = 0;
#	print STDERR "DEBUG ".$self->getParametersString();
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
#	print STDERR "DEBUG RECEIVE = ".join(" ; ", @args);
	my @group = map {$args[$_]} @{$self->{groupsNos}};
#	$self->{logger}->debug("groupsNo=".join(";",@{$self->{groupsNos}})." ; group=".join(";",@group)." ; args=".join(";",@args)) if ($self->{logger}->is_debug());
	my $groupId = join($self->{internalSeparator}, @group);
	my $value = $args[defined($self->{valueArgNo})?$self->{valueArgNo}:(scalar(@args)-1)];
	if ($self->{consecutiveGroups}) {
		if (defined($self->{data}) && ($groupId ne $self->{data})) { # changing group
			$self->_sendToNext($self->{data}, $self->{nb}, $self->{sum}) if (defined($self->{nextConsumer}));
			$self->{nb} = undef;
			$self->{sum} = undef;
		}
		$self->{data} = $groupId; # if first or changed (otherwise a=a)
		if ($value ne "NaN") {
			$self->{nb}++;
			$self->{sum} += $value;
		} else {
			$self->{nbNaN}++;
			$self->{sum} = "NaN" unless (defined($self->{sum}));
		}
	} else {
		my $groupNo = $self->{data}->{$groupId};
		if (!defined($groupNo)) {
			$groupNo=defined($self->{nb})?scalar(@{$self->{nb}}):0;
			$self->{data}->{$groupId} = $groupNo;
		}
		if ($value ne "NaN") {
			$self->{nb}->[$groupNo]++;
			$self->{sum}->[$groupNo] += $value;
			$self->{logger}->debug("adding value $value to group $groupNo '$groupId': nb=".$self->{nb}->[$groupNo].", sum=".$self->{sum}->[$groupNo]) if ($self->{logger}->is_debug());
		} else {
			$self->{nbNaN}++;
			$self->{sum}->[$groupNo] = "NaN" unless (defined($self->{sum}->[$groupNo]));
		}
	}
}



=head2 finalize($footer)


=cut

sub finalize {
	my ($self, $footer) = @_;
	if (defined($self->{data})) {
		if ($self->{consecutiveGroups}) {
			$self->_sendToNext($self->{data}, $self->{nb}, $self->{sum}) if (defined($self->{nextConsumer}));
		} else {
			foreach my $id (sort { $self->{data}->{$a} <=> $self->{data}->{$b} } keys %{$self->{data}}) { # in the order they were received
				my $groupNo = $self->{data}->{$id};
				$self->_sendToNext($id, $self->{nb}->[$groupNo], $self->{sum}->[$groupNo]);
			}
		}
	} else {
		$self->{logger}->logwarn("No value received (receiveScore has not been called at all), nothing sent to the next consumer (if any)");
	}
	$self->{logger}->logwarn($self->{nbNaN}." NaN values discarded from average") if (!$self->{noNaNWarning} && ($self->{nbNaN}>0));
	
	$self->SUPER::finalize($footer);
}


sub _sendToNext {
	my ($self, $groupId, $nb, $sum) = @_;
	my @group = split($self->{internalSeparator}, $groupId);
	my $compareTo;
	$nb = 0 if (!defined($nb));
	if ($self->{checkSameNumberByGroup} || $self->{downscaleRanks}) {
		if (defined($self->{expectedNumberByGroup})) {
			$compareTo = $self->{expectedNumberByGroup};
		} else {
#			print STDERR "DEBUG ELSE group=$groupId nb=$nb sum=$sum ; ".(defined($self->{observedNbByGroup})?$self->{observedNbByGroup}:"undef")."\n";
			$self->{observedNbByGroup} = $nb unless (defined($self->{observedNbByGroup}));
			$compareTo = $self->{observedNbByGroup};
		}
		$self->{logger}->logwarn("The number of values for group $groupId is $nb: different from $compareTo.") if ($nb != $compareTo);
	}
	my $res = "NaN";
	if ($sum ne "NaN") {
		$res = $sum/$nb;
		if ($self->{downscaleRanks}) {
			$res /= $nb;
			if (($nb != $compareTo)) {
				$self->{logger}->logwarn("Option downscaleRanks is enabled but different number of values by group: the ranks sum property will not be satisfied.") if  (!$self->{alreadyWarnedAboutDownscale});
				$self->{alreadyWarnedAboutDownscale} = 1;
			}
		}
	}
	push(@group, $res);
	$self->{nextConsumer}->receiveScore(@group) if (defined($self->{nextConsumer}));
}



1;


