package Text::TextAnalytics::ScoresConsumer::ScoresWriterConsumer;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::ScoresConsumer::ScoresConsumer;

our $VERSION = $Text::TextAnalytics::VERSION;
our @ISA = qw/Text::TextAnalytics::ScoresConsumer::ScoresConsumer/;

=head1 NAME

Text::TextAnalytics::ScoresConsumer::ScoresWriterConsumer - writes scores to a file

=head1 DESCRIPTION

writes to the file and sends the same arguments immediately

=cut

my %defaultOptions = ( 
					   "filename" => "scores.txt", 
					   "columnSeparator" => "\t"
					  ); 

# class variables describing the behaviour ("parameters") (see getParametersString)
our @parametersVars = (
					   "filename",
					  );



=head2 new($class, $params)

$params is a hash ref which optionaly defines the following parameters:
 
=over 2

=item * filename: name of the file to write to. default is "scores.txt"

=item * fileHandle: if defined, scores are written to this stream (filename is ignored)

=item * columnSeparator: default is tab

=back

=cut

sub new {
	my ($class, $params) = @_;
	my $self = $class->SUPER::new($params);
	foreach my $param (keys %defaultOptions) {
#		print STDERR " debug: param key=$param\n";
		$self->{$param} = $defaultOptions{$param} if (!defined($self->{$param}));
	}
	if (!defined($self->{fileHandle})) {
		$self->{createdNewFile} = 1;
		open($self->{fileHandle}, ">:encoding(".$self->{encoding}.")", $self->{filename}) or confess("can not open file '".$self->{filename}."'");
	}
	my $old_fh = select($self->{fileHandle}); 
	$| = 1;
	select($old_fh); 
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


=head2 initialize($header)

if defined, writes the header to the file.

=cut

sub initialize {
	my ($self, $header) = @_;
	$self->SUPER::initialize($header);
	my $fh = $self->{fileHandle};
	print $fh $header if (defined($header));
}


=head 2 receiveScore(@data)

see superclass 

=cut

sub receiveScore {
	my $self = shift;
	my $fh = $self->{fileHandle};
	print $fh join($self->{columnSeparator}, @_)."\n";
	$self->{nextConsumer}->receiveScore(@_) if (defined($self->{nextConsumer}));
}



=head2 finalize($footer)

if defined, writes the footer to the file. 

=cut

sub finalize {
	my ($self, $footer) = @_;
	my $fh = $self->{fileHandle};
	print $fh $footer if (defined($footer));
	if ($self->{createdNewFile}) {
		close($fh);
	}
	$self->SUPER::finalize($footer);
}




1;


