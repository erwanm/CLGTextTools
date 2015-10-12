package Text::TextAnalytics::Tokenizer::BasicWordTokenizer;

use strict;
use warnings;
use Carp;

our $VERSION = $Text::TextAnalytics::VERSION;


=head1 NAME

Text::TextAnalytics::Tokenizer::BasicWordTokenizer - a very simple tokenizer (keeps punctuation)

ISA = Text::TextAnalytics::Tokenizer::Tokenizer


=head1 DESCRIPTION

=cut

my %defaultOptions = ( "toLowercase" => 0, "detachPunctuation" => 0, "detachPunctuationOldVersion" => 0); 
my @parametersVars = keys %defaultOptions;

=head2 new($class, $paramsHash)

parameters as a hash ref, allowed (all 0 by default): 

=over 2

=item * toLowercase: clear

=item * detachPunctuation: "sure!" -> ( "sure" ; "!")

=item *  detachPunctuationOldVersion: slightly different regex: "..." -> (".", ".", ".");  and does not detach pipe char

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

see superclass

=cut

sub tokenize {
	my $self=shift;
	#print "debug arg=$_[0]\n";
	$_ = shift;
	if ($self->{toLowercase}) {
		$_ = lc($_);
	}
	if ($self->{detachPunctuationOldVersion}) {
		s/([^\w|\s])/ $1 /g;
	} elsif ($self->{detachPunctuation}) {
		s/([^\w\s]+)/ $1 /g;
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
