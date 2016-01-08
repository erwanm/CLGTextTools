package CLGTextTools::Observations::WordObsFamily;

# EM June 2015
# 
#
# * to avoid n-grams which span over two sentences or documents,
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
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readTextFileLines arrayToHash assignDefaultAndWarnIfUndef/;
use CLGTextTools::Observations::ObsFamily;
use Data::Dumper::Simple;

our @ISA=qw/CLGTextTools::Observations::ObsFamily/;


our $gramSeparator = " ";
our $startLimitToken = "#UNIT_START#";
our $endLimitToken = "#UNIT_END#";
our $unknownToken = "___";

sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params, __PACKAGE__);
    $self->{wordTokenization} = assignDefaultAndWarnIfUndef("wordTokenization", $params->{wordTokenization}, 1, $self->{logger});
    if (defined($params->{vocab})) {
	$self->{logger}->debug("vocab resources parameter found: ".$params->{vocab}) if ($self->{logger});
	$self->{logger}->trace("Vocab hash content = ".Dumper($params->{vocab})) if ($self->{logger});
	foreach my $vocabId (keys %{$params->{vocab}}) {
	    $self->{logger}->trace("adding vocab entry for key:'$vocabId', file:'".$params->{vocab}->{$vocabId}."'") if ($self->{logger});
	    $self->{vocab}->{$vocabId}->{filename} = $params->{vocab}->{$vocabId};
	}
    }
    return $self;
}


sub addObsType {
    my $self = shift;
    my $obsType = shift;

    if (defined($self->{observs}->{$obsType})) {
	cluckLog($self->{logger}, "Ignoring observation type '$obsType', already initialized.");
    } else {
	$self->{observs}->{$obsType} = {};
	my ($patternStr, $lc, $sl, $vocabId) = ($obsType =~ m/^WORD\.([TS]+)\.lc([01])\.sl([01])(?:\.(.+))?$/);
	confessLog($self->{logger}, "Invalid obs type '$obsType'") if (!length($patternStr) || !length($lc) || !length($sl));
	$self->{logger}->debug("Adding obs type '$obsType': pattern='$patternStr', lc='$lc', sl='$sl'") if ($self->{logger});
	$self->{params}->{$obsType}->{lc} = (defined($lc) && ($lc eq "1"));
	$self->{params}->{$obsType}->{sl} = (defined($sl) && ($sl eq "1"));
	if (defined($vocabId)) {
	    $self->{logger}->debug("Obs type '$obsType' requires vocab id '$vocabId'") if ($self->{logger});
	    $self->{params}->{$obsType}->{vocabId} = $vocabId;
	}
	$self->{lc} = $self->{lc} || $self->{params}->{$obsType}->{lc};
	my @pattern;
	for (my $i=0; $i<length($patternStr); $i++) {
	    $pattern[$i] = (substr($patternStr, $i,1) eq "T");
	}
	$self->{params}->{$obsType}->{pattern} = \@pattern;
	$self->{nbDistinctNGrams}->{$obsType} = 0;
	$self->{nbTotalNGrams}->{$obsType} = 0;
    }

}




#
# Vocabulary file loaded at first use (to avoid reading the file if not used).
# A vocab file contains exactly one token by line.
#
sub getVocab {
    my $self=  shift;
    my $vocabId = shift;

    my $vocab = $self->{vocab}->{$vocabId}->{data};
    if (!defined($vocab)) {
	my $vocabFile = $self->{vocab}->{$vocabId}->{filename};
	$self->{logger}->debug("loading vocabulary '$vocabId' from file '$vocabFile'") if ($self->{logger});
	$vocab = arrayToHash( readTextFileLines($vocabFile,1,$self->{logger}) );
	$self->{vocab}->{$vocabId}->{data} = $vocab;
    }
    return $vocab;
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
	$text =~ s/^\s+//; # remove possible whitespaces at the start and end of the text
	$text =~ s/\s+$//;
    }
    $self->{logger}->debug("Computing list of tokens") if ($self->{logger});
#    $self->{logger}->trace("TEXT='$text'") if ($self->{logger});
    my @tokens = split(/\s+/, $text);
    my $nbTokens = scalar(@tokens);
    $self->{logger}->debug("Adding text: $nbTokens tokens.") if ($self->{logger});
#    $self->{logger}->trace(join("||", @tokens)) if ($self->{logger});
    my @lcTokens;
    @lcTokens = map {lc} (@tokens) if ($self->{lc});
    my @tokensCase = (\@tokens, \@lcTokens); # tokensCase[1] not initialized if lc not needed
    my %vocabTokens;

    foreach my $obsType (keys %{$self->{observs}}) {
	my $p = $self->{params}->{$obsType}->{pattern};
	my $lc =  $self->{params}->{$obsType}->{lc};
	my $selectedTokens = $tokensCase[$lc];
	my $vocabId = $self->{params}->{$obsType}->{vocabId};
	if (defined($vocabId)) {
	    $self->{logger}->debug("looking for vocab '$vocabId' (addText, type $obsType)") if ($self->{logger});
	    my $vocab = $self->getVocab($vocabId);
	    confessLog($self->{logger}, "Error for obs type $obsType: no vocabulary found for vocab id '$vocabId'") if (!defined($vocab));
	    my @tokensVocab = map { defined($vocab->{$_}) ? $_ : $unknownToken } @$selectedTokens;
	    $selectedTokens = \@tokensVocab;
	}
	$self->addStartEndNGrams($selectedTokens, $obsType) if ($self->{params}->{$obsType}->{sl});
	for (my $i=0; $i<$nbTokens; $i++) {
	    if ($i + scalar(@$p) <= $nbTokens) {
		my @ngram;
		for (my $j=0; $j<scalar(@$p); $j++) {
		    push(@ngram, $selectedTokens->[$i+$j]) if ($p->[$j]);
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
    
    confessLog($self->{logger}, "Bug: empty ngram!") if (length($ngramStr)==0);
    $self->{logger}->trace("Adding ngram '$ngramStr' for obsType '$obsType'") if ($self->{logger});
    $self->{nbDistinctNGrams}->{$obsType}++ if (!defined($self->{observs}->{$obsType}->{$ngramStr}));
    $self->{observs}->{$obsType}->{$ngramStr}++;
    $self->{nbTotalNGrams}->{$obsType}++;
}


sub addStartEndNGrams {
    my $self = shift;
    my $tokens = shift;
    my $obsType = shift;
    $self->{logger}->debug("Adding sentence limits ngrams for obsType '$obsType'") if ($self->{logger});
    my $p = $self->{params}->{$obsType}->{pattern};
    my $lc =  $self->{params}->{$obsType}->{lc};
    my $length = scalar(@$p);
    my $n = scalar(@$tokens);
    for (my $nbPart1=1; $nbPart1<$length; $nbPart1++) {
	my @ngramStart;
	my @ngramEnd;
	for (my $i=0; $i< $nbPart1; $i++) {
	    if ($p->[$i]) {
		push(@ngramStart, $startLimitToken);
		push(@ngramEnd, $tokens->[$n -$nbPart1 +$i]) if ($n -$nbPart1 +$i >0);
	    }
	}
	for (my $i=$nbPart1; $i< $length; $i++) {
	    if ($p->[$i]) {
		push(@ngramStart, $tokens->[$i -$nbPart1]) if ($i - $nbPart1 < $n);
		push(@ngramEnd, $endLimitToken);
	    }
	}
	$self->_addNGram(\@ngramStart, $obsType) if ($length-$nbPart1 < $n);
	$self->_addNGram(\@ngramEnd, $obsType) if ($nbPart1 < $n);
    }
}




1;
