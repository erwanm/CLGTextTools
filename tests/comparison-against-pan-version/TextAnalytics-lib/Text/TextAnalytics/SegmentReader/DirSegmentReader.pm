package Text::TextAnalytics::SegmentReader::DirSegmentReader;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::SegmentReader::SegmentReader;
use IO::File;

our @ISA = qw/Text::TextAnalytics::SegmentReader::SegmentReader/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::SegmentReader::DirSegmentReader - reads a given directory file by file

ISA = Text::TextAnalytics::SegmentReader::SegmentReader

=cut

my @parametersVars = ("dirname");

=head1 DESCRIPTION

the data is contained in different files (each correspoing to a segment), and all (and only) these files are in the same directory.

=head2 new($class, $params)

$params->{dirname} must be set (the directory name)

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
#	$self->{dirname} = $params->{dirname};
	$self->{id} = $self->{dirname};
	$self->initReader();
	return $self; 	
}


sub initReader {
	my $self = shift;
	$self->SUPER::initReader();
	opendir($self->{dirHandle}, $self->{dirname}) or confess("can not open directory '".$self->{dirname}."'");
	$self->{logger}->debug("Initializing reader");
	$self->{currentId} = undef;
}



=head2 getParametersString($prefix)

see superclass

=cut

sub getParametersString {
	my $self = shift;
	my $prefix = shift;
	my $str = $self->SUPER::getParametersString($prefix);
	$str .= Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars,$prefix,1);
	return $str;
}


=head2 getId()

see superclass

=cut

sub getId {
	my $self = shift;
	return $self->{dirname};
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
	if (defined($self->{dirHandle})) {
		close($self->{dirHandle});
		$self->{dirHandle} = undef;
		$self->{currentId} = undef;
	}
}


=head2 readNextSegment()

see superclass

=cut

sub readNextSegment {
	my $self = shift;
	my $dh = $self->{dirHandle};
	if (defined($dh)) {
		my $filename = $self->_getNextValidFilename($dh);
		return undef if (!defined($filename));
		open(my $fh, "<:encoding(".$self->{encoding}.")", $self->{dirname}."/".$filename) or confess("can not open file '$filename' in directory '".$self->{dirname}."'");
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
	my $dh = $self->{dirHandle};
	if (defined($dh)) {
		my $filename = $self->_getNextValidFilename($dh);
		return (defined($filename));
	}
	return undef;
}


# private method
sub _getNextValidFilename {
	my ($self, $dh) = @_;
	my $filename;
	do {
		$filename = readdir($dh);
		$self->{logger}->debug("next entry in dir= '".(defined($filename)?$filename:"NULL")."'");
		$self->{logger}->debug("entry  ".(defined($filename)?$filename:"NULL")." excluded.") if (defined($filename) && (($filename =~ /^\.\.?$/) || (-d $self->{dirname}."/".$filename)));
	} while (defined($filename) && (($filename =~ /^\.\.?$/) || (-d $self->{dirname}."/".$filename)));
	$self->{logger}->debug("selected entry in dir= '".(defined($filename)?$filename:"NULL")."'");
	return $filename;
}



1;
