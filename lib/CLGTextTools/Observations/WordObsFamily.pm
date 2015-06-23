package CLGTextTools::Observations::WordObsFamily;

# EM June 2015
# 
# addText expects an array of tokens: 
#
# * to avoid n-grams which span over two two sentences or documents,
# use two distinct calls to addText: ``addText(sentence1);
# addText(sentence2);``
#
# * similarly, setting ``sentenceLimits`` to 1 will cause the
# adjunction of special tokens before and after the wole sequence
# of tokens with which addText is called.
#
# * If the input is a text file with arbitrary line breaks, then
# all the tokens must be given in a single call to addText (i.e.
# not line by line).
#

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog/;
use CLGTextTools::Observations::ObsFamily;

our @ISA=qw/CLGTextTools::Observations::ObsFamily/;


our $gramSeparator = " ";
our $startLimitToken = "#START_SENTENCE#";
our $endLimitToken = "#END_SENTENCE#";


sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params);
    $self->{wordTokenization} = 1 unless (defined($params->{wordTokenization}) && ($params->{wordTokenization} == 0));
    return $self;
}


sub addObsType {
    my $self = shift;
    my $obsType = shift;

    if (defined($self->{observs}->{$obsType})) {
	warnLog($self->{logger}, "Ignoring observation type '$obsType', already initialized.");
    } else {
	$self->{observs}->{$obsType} = {};
	my ($patternStr, $lc, $sl) = ($obsType =~ m/WORD\.([TS]+)\.lc([01])\.sl([01])/);
	confessLog($self->{logger}, "Invalid obs type '$obsType'") if (!length($lc) || !length($lc) || !length($sl));
	$self->{logger}->debug("Adding obs type '$obsType': pattern='$patternStr', lc='$lc', sl='$sl'") if ($self->{logger});
	$self->{params}->{$obsType}->{lc} = (defined($lc) && ($lc eq "1"));
	$self->{params}->{$obsType}->{sl} = (defined($sl) && ($sl eq "1"));
	$self->{lc} = (defined($lc) && ($lc eq "1")) ? 1 : 0;
	my @pattern;
	for (my $i=0; $i<length($patternStr); $i++) {
	    $pattern[$i] = (substr($patternStr, $i,1) eq "T");
	}
	$self->{params}->{$obsType}->{pattern} = \@pattern;
	$self->{nbNGrams}->{$obsType} = 0;
    }

}


#
# a subclass which requires some other obs types must return their ids in this method.
#
sub requiresObsTypes {
    my $self = shift;
    return [];
}



# addText($text)
#
#
sub addText {
    my $self = shift;
    my $text = shift;

    if ($self->{wordTokenization}) {
	$self->{logger}->debug("Tokenizing input text") if ($self->{logger});
	$text =~ s/([^\w\s]+)/ $1 /g;
    }
    $self->{logger}->debug("Computing list of tokens") if ($self->{logger});
    my @tokens = split(/\s+/, $text);
    my $nbTokens = scalar(@tokens);
    $self->{logger}->debug("Adding text: $nbTokens tokens.") if ($self->{logger});
    my @lcTokens;
    @lcTokens = map {lc} (@tokens) if ($self->{lc});
    my @tokensCase = (\@tokens, \@lcTokens); # tokensCase[1] not initialized if lc not needed

    $self->addStartEndNGrams(\@tokensCase);
    for (my $i=0; $i<$nbTokens; $i++) {
	foreach my $obsType (keys %{$self->{observs}}) {
	    my $p = $self->{params}->{$obsType}->{pattern};
	    my $lc =  $self->{params}->{$obsType}->{lc};
	    if ($i + scalar(@$p) < $nbTokens) {
		my @ngram;
		for (my $j=0; $j<scalar(@$p); $j++) {
		    push(@ngram, $tokensCase[$lc]->[$i+$j]) if ($p->[$j]);
		}
		$self->_addNGram(\@ngram, $obsType);

	    }
	}
    }
}


#
# TODO: possible efficiency issue? calling this method every time an ngram is added.
# Do some time tests.
#
sub _addNGram {
    my $self = shift;
    my $ngramArray = shift;
    my $obsType = shift;

    my $ngramStr = join($gramSeparator, @$ngramArray);
    $self->{logger}->trace("Adding ngram '$ngramStr' for obsType '$obsType'") if ($self->{logger});
    $self->{observs}->{$obsType}->{$ngramStr}++;
    $self->{nbNGrams}->{$obsType}++;
}


sub addStartEndNGrams {
    my $self = shift;
    my $tokensCase = shift;
    foreach my $obsType (keys %{$self->{observs}}) {
	if ($self->{params}->{$obsType}->{sl}) {
	    $self->{logger}->debug("Adding sentence limits ngrams for obsType '$obsType'") if ($self->{logger});
	    my $p = $self->{params}->{$obsType}->{pattern};
	    my $lc =  $self->{params}->{$obsType}->{lc};
	    my $length = scalar(@$p);
	    my $n = scalar(@{$tokensCase->[0]});
	    for (my $i=1; $i<$length; $i++) {
		my @ngramStart;
		my @ngramEnd;
		for (my $j=0; $j < $i; $j++) {
		    push(@ngramStart, $tokensCase->[$lc]->[$j]);
		    unshift(@ngramEnd, $tokensCase->[$lc]->[$n -$j -1]);
		}
		for (my $j=$i; $j<$length; $j++) {
		    unshift(@ngramStart, $startLimitToken);
		    push(@ngramEnd, $endLimitToken);
		}
		$self->_addNGram(\@ngramStart, $obsType);
		$self->_addNGram(\@ngramEnd, $obsType);
	    }
	}
    }
}




1;
