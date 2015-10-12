package Text::TextAnalytics::SegmentReader::SegmentReader;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::SegmentReader::MultiRange;

our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::SegmentReader::SegmentReader - abstract class for objects responsible to read the data

=head1 DESCRIPTION

subclasses must override new, closeReader, getId, readNextSegment and skipNextSegment.
they should preferably override getCurrentId.

=cut

our $defaultEncoding = "utf-8";

my %defaultOptions = ( 
					   "multiRange" => undef,
					   "encoding" => $defaultEncoding 
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
our @parametersVars = (
					   "encoding"
					  );



=head2 new($class, $params)

must be called by subclasses constructors.
$params is an hash ref which optionaly defines the following parameters:
 
=over 2

=item * multiRange: a range of indexes describing the portions to read, in the form start1-end1[;start2-end2;...]. for example "0-100;150-200" means read the first 100 segments, skip the 50 next lines, read 50 more segments, skip the remaining ones.

=item * encoding: string

=back

=cut
sub new {
	my ($class, $params) = @_;
	my $self;
	%$self = %defaultOptions;
	$self->{encoding} = $params->{encoding} || $defaultEncoding;
	$self->{logger} = Log::Log4perl->get_logger(__PACKAGE__); 
	foreach my $opt (keys %$params) {
		$self->{$opt} = $params->{$opt};
	}
	$self->{multiRangeStr} = $self->{multiRange};
	bless($self, $class);
	return $self; 	
}


=head2 initReader()

must be called by subclasses!

=cut 

sub initReader {
	my $self = shift;
	$self->{position} = 0;
	$self->{nextSegmentInQueue} = undef;
	$self->{nbSkipped} = 0;
	# create multiRange object with parameter if supplied, or with "0-" which means "all segments"
	$self->{multiRange} = Text::TextAnalytics::SegmentReader::MultiRange->new(defined($self->{multiRangeStr})?$self->{multiRangeStr}:"0-");
	$self->{nbSegmentsTotal} = $self->{multiRange}->getTotal();
	my $firstRange = $self->{multiRange}->nextRange();
	if (defined $firstRange) {
		$self->{currentStart} = $firstRange->[0];
		$self->{currentEnd} = $firstRange->[1];
	} else {
		$self->{logger}->logwarn("no segment to read!");
		$self->{currentStart} = 0;
		$self->{currentEnd} = 0;
	}
}



=head2 resetReader()

restart the reader as if nothing has been read yet
=cut


sub resetReader {
	my $self = shift;
	$self->closeReader();
	$self->initReader();
	
}

=head2 getParametersString($prefix)

returns a string describing the current parameters. The string can span on several lines,
in which case $prefix is added at the beginning of every line.

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix);
	$str .= $prefix."multiRange=".$self->{multiRange}->asString()."\n";
	return $str;
}




=head2 getProgress()

default: if possible (last segment defined in multiRange), returns the current progression i.e. position / nb-total (value between 0 and 1).
returns undef otherwise.
this method can be overriden by subclasses but must return a value between 0 and 1

=cut

sub getProgress {
	my $self = shift;
	if (defined($self->{nbSegmentsTotal})) {
		return $self->getNbAlreadyRead() / $self->{nbSegmentsTotal};
	} else {
		return undef;
	}
}

sub getPosition {
	my $ self= shift;
	return $self->{position}
}


=head2 getNbAlreadyRead()

returns the number of segments which have been actually read so far (not counting the skipped segments)

=cut

sub getNbAlreadyRead {
	my $self = shift;
	return $self->{position} - $self->{nbSkipped};
}



=head2 _obtainNextSegment()

private method, normally no need to override.
returns 1 and sets $self->{nextSegmentInQueue} if there is a next segment, 0 otherwise

=cut 

sub _obtainNextSegment {
	my $self = shift;
	if (!defined($self->{nextSegmentInQueue})) {

		# if after currentEnd, go to next range or close
		# remark: while necessary only in case of 0 length range(s): N-N
		while (defined($self->{currentEnd}) && ($self->{position} >= $self->{currentEnd})) { # remark: currentEnd=undef means "no end bound"
			my $nextRange = $self->{multiRange}->nextRange();
			if (defined($nextRange)) {
				$self->{currentStart} = $nextRange->[0];
				$self->{currentEnd} = $nextRange->[1];
			} else {
				$self->closeReader(); # $self->{nextSegmentInQueue} is already undef
				return 0;
			}
		}
	
		# arriving here only if the end condition is satisfied (and currentStart<currentEnd, i.e. at least one segment to read)
		# if before start position, skip until finding it
		while (($self->{position} < $self->{currentStart})) {
			if (!$self->skipNextSegment()) {
				$self->closeReader();  # $self->{nextSegmentInQueue} is already undef
				return 0;
			} else {
				$self->{nbSkipped}++;
			}
			$self->{position}++;
		} 
		
		# obtain current segment or close if failure
		if (!defined($self->{nextSegmentInQueue} = $self->readNextSegment())) {
			$self->closeReader();
			return 0;
		}
		
		return 1;
	}
}


=head2 next()

returns the next segment if any, undef otherwise.

caution: no need for hasNext() since "while (defined(my $s = next()))" is ok, BUT
do not use "while (my $s = next())" unless it is guaranted that the data is NEVER empty (e.g. empty lines), since
the empty string is returned in this case (which evaluates to false in perl). using hasNext() also avoids this problem.

=cut

sub next {
	my $self = shift;
	$self->_obtainNextSegment();
	my $segment = $self->{nextSegmentInQueue};
	if (defined($segment)) {
		$self->{position}++;
		$self->{nextSegmentInQueue} = undef;
	}
	return $segment;	
}		


=head2 hasNext()

as its name suggests. usually useless (perl style next()).

=cut

sub hasNext {
	my $self = shift;
	return $self->_obtainNextSegment();
}


=head2 getId()

returns a string id

=cut


=head2 closeReader()

the reader is informed that all reading is done.
do any necessary end of process task (closing file...)

=cut



=head2 readNextSegment()

returns the next segment if any, undef otherwise.
subclasses do not need to check the startAt/endAt nor whether there is already a segment in queue etc.:
this method is called only when all necessary checks have been performed

=cut


=head2 skipNextSegment()

skips the next segment, returns true if ok false otherwise.
subclasses do not need to check the startAt/endAt nor whether there is already a segment in queue etc.:
this method is called only when all necessary checks have been performed

=cut


=head2 getCurrentId()

returns an id for the last segment read with next()
by default this is the result of getPosition()-1

=cut

sub getCurrentId {
	my $self = shift;
	return $self->getPosition() -1;
}


1;


