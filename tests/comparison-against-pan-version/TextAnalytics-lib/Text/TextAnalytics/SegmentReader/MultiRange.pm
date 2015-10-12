package Text::TextAnalytics::SegmentReader::MultiRange;

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use base 'Exporter';

our @EXPORT_OK=qw/$rangeSeparator/;

our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::SegmentReader::MultiRange - represents a "multi-range" set of indexes of the form start1-end1[,start2-end2,...]

=head1 DESCRIPTION

=cut

our $rangeSeparator = ",";

=head2 new($class, $multiRangeString)

call with empty $multiRangeString to create a new empty object.

=cut

sub new {
	my $class = shift;
	my $multiRangeString = shift || "";
	my $self;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__); 
#	print STDERR "DEBUG1 adding $multiRangeString\n\n";
	my @rangesStr = split(/$rangeSeparator/, $multiRangeString);
	$self->{ranges} = [];
	$self->{total}=0;
	$self->{nextRange} = 0;
	bless($self, $class);
	foreach my $rangeStr (@rangesStr) {
#	print STDERR "DEBUG adding '$rangeStr'...";
		if (length($rangeStr) > 0) {
			if ($rangeStr !~ m/^[^-]+-[^-]*$/) {
				$self->{logger}->logconfess("Invalid range expression '$rangeStr'");
			}
			my ($start, $end) = ($rangeStr =~ m/^(.+)-(.*)$/);
			$end = undef if (length($end) == 0);
			$self->addRange($start, $end);
		}
	}
	return $self; 	
}



=head2 addRange($start, $end) 

=cut

sub addRange {
	my ($self, $start, $end) = @_;
	$start += 0; # to ensure that perl interprets these as integers, especially in the case "000": otherwise perl does not know that 000 = 0 ...
	$end += 0 if (defined($end));
	$self->{logger}->logconfess("Invalid range: end=$end < start=$start") if (defined($end) && ($end < $start));
	my @ranges = @{$self->{ranges}};
#	print STDERR "curr ranges = ".$self->asString()."\n";
	push(@ranges, [ $start, $end ]);
	if (defined($end)) {
		$self->{total} += ($end-$start);
	} else {
		$self->{total} = undef;
	}
	@{$self->{ranges}} = sort {$a->[0] <=> $b->[0]} @ranges;
	my $current = 0;
	foreach my $range (@{$self->{ranges}}) { # checking
		$self->{logger}->logconfess("Invalid range found: current=undef but there are remaining range(s).") if (!defined($current));
		$self->{logger}->logcarp("Range overlap found: current=$current > start=".$range->[0]) if ($current > $range->[0]);
		$current = $range->[1];
	}
}

=head2 asString()

=cut

sub asString() {
	my $self = shift;
	my @ranges;
	foreach my $range (@{$self->{ranges}}) { 
	my $start = $range->[0];
		my $end = defined($range->[1])?$range->[1]:"";
		push(@ranges, "$start-$end");
	}
	return join($rangeSeparator, @ranges);
}

=head2 isIncluded($index)

=cut

sub isIncluded {
	my ($self, $index) = @_;
	my $i=0;
 	while (($i<scalar($self->{ranges})) && defined($self->{ranges}->[$i]->[1]) && ($index>= $self->{ranges}->[$i]->[1])) {
 		$i++;
 	}
 	return 0 if ($i==scalar($self->{ranges}));
 	return 1 if (!defined($self->{ranges}->[$i]->[1]));
 	return ($self->{ranges}->[$i]->[0] <= $index);	
}



=head2 getTotal()

can be undef if there is no end bound.

=cut

sub getTotal {
	my $self=shift;
	return $self->{total};
}

=head2 resetRangeIterator()

=cut
sub resetRangeIterator {
	my $self = shift;
	$self->{nextRange} = 0;
}

=head2 nextRange() 

undef if no more range. returns a list ref, list contains [ start, end ]

=cut
sub nextRange {
	my $self = shift;
	if ($self->{nextRange} < scalar(@{$self->{ranges}})) {
		my $range = $self->{ranges}->[$self->{nextRange}];
		$self->{nextRange}++;
		return $range;
	} else {
		return undef;
	}
}


=head2 generateEqualSubRanges($nb)

returns a list of $nb MultiRange objects which cover exactly this multi-range and are all the same length (except for the remaining)
only possible if the end bound is defined.

=cut

sub generateEqualSubRanges {
	my ($self, $nb) = @_;
	my $nbTotal = $self->getTotal();
	$self->{logger}->logconfess("End bound must be defined") if (!defined($nbTotal));
	$self->{logger}->logconfess("MultiRange object must have minimum length 1") if ($nbTotal==0);
	my $size = int($nbTotal / $nb);
	my $left = $nbTotal - $size * $nb;
	if ($left > 0) {
		$size++;
	}
	my @newRanges;
	my $rangeNo = 0;
	my $currEnd = $self->{ranges}->[$rangeNo]->[1];
	my $currPos = $self->{ranges}->[$rangeNo]->[0];
	for (my $newRangeNo=0; $newRangeNo < $nb; $newRangeNo++) {
		$newRanges[$newRangeNo] = new(__PACKAGE__);
		my $sizeRequiredNewRange = $size;
		while (defined($rangeNo) && ($sizeRequiredNewRange > 0)) {
			my $sizeSubRange = ($currPos + $sizeRequiredNewRange <= $currEnd)?$sizeRequiredNewRange:($currEnd-$currPos);
			$newRanges[$newRangeNo]->addRange($currPos, $currPos+$sizeSubRange);
			$sizeRequiredNewRange -= $sizeSubRange;
			$currPos += $sizeSubRange;
			if ($currPos == $currEnd) {
				$rangeNo++;
				if ($rangeNo < scalar(@{$self->{ranges}})) {
					$currEnd = $self->{ranges}->[$rangeNo]->[1];
					$currPos = $self->{ranges}->[$rangeNo]->[0];
				} else {
					$rangeNo = undef;
				}
			}
		}
	}
	$self->{logger}->logconfess("BUG: something wrong in generateEqualSubRanges!") if (scalar(@newRanges)<$nb);
	return \@newRanges; 
}


=head2 normalize()


=cut

sub normalize {
	my $self = shift;
	my @newRanges = ();
	my ($start, $end);
	foreach my $range (@{$self->{ranges}}) {
		if (!defined($start)) {
			$start = $range->[0];
			$end = $range->[1];
		} else {
			if ($range->[0] <= $end) {
				$end=$range->[1] if ($range->[1] > $end);
			} else {
			    push(@newRanges, [ $start, $end ]);
				$start = $range->[0];
				$end = $range->[1];
			}
		} 
	}
	push(@newRanges, [ $start, $end ]) if (defined($start));
	$self->{ranges} = \@newRanges;
}

1;

