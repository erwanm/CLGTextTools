package Text::TextAnalytics::Tokenizer::CharTokenizer;

use strict;
use warnings;
use Carp;
use Text::TextAnalytics::Tokenizer::Tokenizer;
use Scalar::Util 'blessed';

our @ISA=qw/Text::TextAnalytics::Tokenizer::Tokenizer/;
our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::Tokenizer::CharTokenizer - a char "tokenizer" (which actually does not tokenize anything) 

ISA = Text::TextAnalytics::Tokenizer::Tokenizer

=cut

=head1 DESCRIPTION

this tokenizer only applies some regexps depending on the options and returns the preprocessed string. 

=cut

my %defaultOptions = ( "toLowercase" => 0, "glueWords"=> 0, "mergeWhitespaces" => 0 ); 
my @parametersVars = keys %defaultOptions;


=head2 new($class, $paramsHash)

parameters as a hash ref, allowed (all 0 by default): 

=over 2

=item * toLowercase: clear

=item *  glueWords: "hello there" -> "hellothere"

=item *  mergeWhitespaces -> "hello    there" -> "hello there"

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


=head2 getParametersString($prefix)

see superclass

=cut

sub getParametersString {
	my ($self, $prefix) = @_;
	return Text::TextAnalytics::getParametersStringGeneric($self, \@parametersVars, $prefix);
}


=head2 tokenize($string)

see superclass. returns a string.

=cut

sub tokenize {
	my $self=shift;
	$_ = shift;
	if ($self->{toLowercase}) {
		$_ = lc($_);
	}
	if ($self->{glueWords}) {
		s/\s//g;
	} elsif ($self->{mergeWhitespaces}) {
		s/\s+/ /g;
	}
	return $_;
}



=head2 returnsList()

returns 1

=cut

sub returnsList {
	return 0;
}


1;
