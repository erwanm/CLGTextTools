package Text::TextAnalytics::SegmentReader::ListSegmentReader;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::SegmentReader::SegmentReader;
use IO::File;

our @ISA = qw/Text::TextAnalytics::SegmentReader::SegmentReader/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::SegmentReader::ListSegmentReader - reads the list of data files in a file

ISA = Text::TextAnalytics::SegmentReader::SegmentReader

=cut

my @parametersVars = ("filename");

=head1 DESCRIPTION

the data is contained in different files: each file contains a segment, and the list of files itself is
provided in a file (one file name by line)

=head2 new($class, $params)

$params->{filename} must be set (the list filename)

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
#	$self->{filename} = $params->{filename}; # done automatically previous line
	$self->{id} = $self->{filename};
	$self->initReader();
	return $self; 	
}


sub initReader {
	my $self = shift;
	$self->SUPER::initReader();
	open($self->{fileHandle}, "<:encoding(".$self->{encoding}.")", $self->{filename}) or confess("can not open file '".$self->{filename}."'");
	$self->{currentId} = undef;
}


=head2 getParametersString($prefix)

see superclass

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = $self->SUPER::getParametersString($prefix);
	$str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars,$prefix, 1);
	return $str;
}




=head2 getId()

see superclass

=cut

sub getId {
	my $self = shift;
	return $self->{filename};
}

=head2 getCurrentId()

see superclass

=cut

sub getCurrentId {
	my $self = shift;
	return $self->{currentId};
}

=head2 closeReader()

see superclass

=cut

sub closeReader {
	my $self = shift;
	if (defined($self->{fileHandle})) {
		close($self->{fileHandle});
		$self->{fileHandle} = undef;
		$self->{currentId} = undef;
	}
}


=head2 readNextSegment()

see superclass

=cut

sub readNextSegment {
	my $self = shift;
	my $fh = $self->{fileHandle};
	if (defined($fh)) {
		my $filename = $self->_getNextValidFilename($fh);
		return undef if (!defined($filename));
		open(my $fh, "<:encoding(".$self->{encoding}.")", $filename) or confess("can not open file '$filename'.");
		my $content = "";
		while (my $line = <$fh>) {
			$content .= $line;
		}
		close($fh);
		$self->{currentId} = $filename;
		return $content;
	}
	return undef;
}


=head2 skipNextSegment()

see superclass

=cut

sub skipNextSegment {
	my $self = shift;
	my $fh = $self->{fileHandle};
	if (defined($fh)) {
		my $filename = $self->_getNextValidFilename($fh);
		return (defined($filename));
	}
	return undef;
}

# private method
sub _getNextValidFilename {
	my ($self, $dh) = @_;
	my $fh = $self->{fileHandle};
	my $filename=<$fh>;
	chomp($filename) if (defined $filename);
	return $filename;
}



1;
