package Text::TextAnalytics::Tokenizer::NoPunctuationTokenizer;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::Tokenizer::Tokenizer;

our @ISA=qw/Text::TextAnalytics::Tokenizer::Tokenizer/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::Tokenizer::NoPunctuationTokenizer - simple tokenizer which removes punctuation: more precisely removes any character which is not a letter, a digit, or "_"

ISA = Text::TextAnalytics::Tokenizer::Tokenizer

=head1 DESCRIPTION

=cut

my %defaultOptions = ( "replaceWithSpace" => 1, "toLowercase" => 0, "keepPipe"=> 0 ); 
my @parametersVars = keys %defaultOptions;


=head2 new($class, $paramsHash)

parameters as a hash ref, allowed:

=over 2

=item * replaceWithSpace: 1 by default.  if set, removed characters are replaced with a space to avoid gluing two words: e.g. "hello<br/>" -> "hello" ; "br".   
if 0, then the removed characters are NOT replaced (only removed), e.g. "hello<br/>" -> "hellobr"

=item * toLowercase: clear. 0 by default.

=item * keepPipe: do not consider the pipe char as punctuation (?)  0 by default.

=back

=cut  

sub new {
	my $class = shift;
	my $paramsHash = shift;
	my $self;
	%$self = %defaultOptions;
	foreach my $opt (keys %$paramsHash) {
		$self->{$opt} = $paramsHash->{$opt};
	}
	bless($self, $class);
	return $self;
}



=head2 tokenize($string)

see superclass

=cut

sub getParametersString {
	my ($self, $prefix) = @_;
	return Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix);
}


=head2 tokenize($string)

see superclass

=cut 

sub tokenize {
	my $self=shift;
	$_= shift;
#	print "debug: '$_'\n";
	my $replaceVal =  $self->{replaceWithSpace}?" ":"";
	if ($self->{keepPipe}) { 
		s/[^\w\s|]/$replaceVal/g;
	} else {
		s/[^\w\s]/$replaceVal/g;
	}
	if ($self->{toLowercase}) {
		$_ = lc($_);
	}
	my @tokens = split;
	return \@tokens;
}


=head2 returnsList()

returns 1

=cut

sub returnsList {
	return 1;
}


1;
