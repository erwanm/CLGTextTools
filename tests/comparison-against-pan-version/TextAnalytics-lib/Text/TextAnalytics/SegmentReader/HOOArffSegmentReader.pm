package Text::TextAnalytics::SegmentReader::HOOArffSegmentReader;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::SegmentReader::SegmentReader;
use IO::File;

our @ISA = qw/Text::TextAnalytics::SegmentReader::SegmentReader/;
our $VERSION = $Text::TextAnalytics::VERSION;

=head1 NAME

Text::TextAnalytics::SegmentReader::HOOArffSegmentReader


=cut

my %defaultOptions = ( 
					   "colCurrentWord" => 7,
					   "colsPrevWordsNos" => "9,11,13,15",  # e.g. "2,4,7" 
					   "colsNextWordsNos" => "17,19,21,23",  # e.g. "2,4,7" 
					  ); 


my @parametersVars = ("filename", "colCurrentWord", "colsPrevWords", "colsNextWords");


=head1 DESCRIPTION

ISA = Text::TextAnalytics::SegmentReader::SegmentReader

the data is contained in one file, each line corresponds to a segment.

=head2 new($class, $params)

$params->{filename} must be set (the data file)

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $param (keys %defaultOptions) {
		$self->{$param} = $defaultOptions{$param} if (!defined($self->{$param}));
#		print STDERR " debug: param $param=$self->{$param}\n";
	}
#	$self->{filename} = $params->{filename};
	$self->{id} = $self->{filename};
	@{$self->{colsPrevWords}} = split(/,/, $self->{colsPrevWordsNos});
	@{$self->{colsNextWords}} = split(/,/, $self->{colsNextWordsNos});
	$self->initReader();
	return $self; 	
}


sub initReader {
	my $self = shift;
	$self->SUPER::initReader();
	open($self->{fileHandle}, "<:encoding(".$self->{encoding}.")", $self->{filename}) or confess("can not open file '".$self->{filename}."'");
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


=head2 closeReader()

see superclass

=cut

sub closeReader {
	my $self = shift;
	if (defined($self->{fileHandle})) {
		close($self->{fileHandle});
		$self->{fileHandle} = undef;
	}
}



=head2 getId()

see superclass

=cut

sub getId {
	my $self = shift;
	return $self->{id};
}

=head2 readNextSegment()

see superclass

=cut

sub readNextSegment {
	my $self = shift;
	my $fh = $self->{fileHandle};
	if (defined($fh)) {
		my $line = <$fh>;
		my @cols = ($line =~ m/("[^"]*")/g);
		my @before = map {$cols[$_]} @{$self->{colsPrevWords}};
		my @after = map {$cols[$_]} @{$self->{colsNextWords}};
		return join(" ", @before).$cols[$self->{colCurrentWord}].join(" ", @after);
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
		my $line = <$fh>;
		return defined($line);
	}
	return undef;
}
 

1;
