package CLGTextTools::Observations::POSObsFamily;

#twdoc
#
# Obs family class for POS observations.
#
# POS input is expected to be found in a file ``$file.POS`` containing the output in TreeTagger format (with lemma): ``<token> <POS tag> <lemma>``
#
# ---
# EM July 2015
#
#/twdoc

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readTextFileLines arrayToHash/;
use CLGTextTools::Observations::ObsFamily;
use Data::Dumper::Simple;

our @ISA=qw/CLGTextTools::Observations::ObsFamily/;


our $gramSeparator = " ";
our $startLimitToken = "#START_SENTENCE#";
our $endLimitToken = "#END_SENTENCE#";
our $sentenceEndPOSTag = "SENT";


#twdoc new($class, $params)
#
# see parent, no additional parameters.
#
#/twdoc
sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params, __PACKAGE__);
    return $self;
}


#twdoc addObsType($self, $obsType)
#
# Format of a POS obs type: ``POS.[TSPL]+.sl[01]``
#
# * Pattern:
# ** T = token
# ** S = skip
# ** P = POS tag
# ** L = lemma
# * ``sl`` = sentence limit option
#
#/twdoc
sub addObsType {
    my $self = shift;
    my $obsType = shift;

    if (defined($self->{observs}->{$obsType})) {
	cluckLog($self->{logger}, "Ignoring observation type '$obsType', already initialized.");
    } else {
	$self->{observs}->{$obsType} = {};
	my ($patternStr, $sl) = ($obsType =~ m/^POS\.([TSPL]+)\.sl([01])$/);
	confessLog($self->{logger}, "Invalid obs type '$obsType'") if (!length($patternStr) || !length($sl));
	$self->{logger}->debug("Adding obs type '$obsType': pattern='$patternStr', sl='$sl'") if ($self->{logger});
	$self->{params}->{$obsType}->{sl} = (defined($sl) && ($sl eq "1"));
	$self->{sl} = $self->{sl} || $self->{params}->{$obsType}->{sl};
 	my @pattern;
	for (my $i=0; $i<length($patternStr); $i++) {
	    my $c = substr($patternStr, $i,1);
	    if ($c eq "S") {  # -1 if S, 0 if T, 1 if P, 2 if L.
		$pattern[$i] = -1;
	    } elsif ($c eq "T") {
		$pattern[$i] = 0;
	    } elsif ($c eq "P") {
		$pattern[$i] = 1;
	    } elsif ($c eq "L") {
		$pattern[$i] = 2;
	    }
	}
	$self->{params}->{$obsType}->{pattern} = \@pattern;
	$self->{params}->{$obsType}->{length} = scalar(@pattern);
	$self->{nbDistinctNGrams}->{$obsType} = 0;
	$self->{nbTotalNGrams}->{$obsType} = 0;
    }

}







#twdoc addText($text)
#
# see parent.
#
# * Remark: in this class the ``$text`` input is an array ref ``$text->{i}->{column}`` with the following format:
# ** ith token if column=0;
# **  POS tag for ith token if column=1;
# **  lemma for ith token if column=2
#
#/twdoc
sub addText {
    my $self = shift;
    my $tokens = shift;

    my $nbTokens = scalar(@$tokens);
    $self->{logger}->debug("Adding text: $nbTokens tokens.") if ($self->{logger});
    my @sentences;
    if ($self->{sl}) { # at least one obs type requires sentence limits: split in sentences.
	$self->{logger}->debug("Adding text: splitting by sentences") if ($self->{logger});
	my $i=0;
	while ($i<$nbTokens) {
	    my @sent;
	    while ( ($i<$nbTokens) && ($tokens->[$i]->[1] ne $sentenceEndPOSTag) ) {
		push(@sent, $tokens->[$i]);
		$i++;
	    }
	    if ($i<$nbTokens) {
		push(@sent, $tokens->[$i]); # push "SENT"
		$i++;
	    }
	    push(@sentences, \@sent);
	}
	$self->{logger}->debug("Found ".scalar(@sentences)." sentences") if ($self->{logger});
    }

    foreach my $obsType (keys %{$self->{observs}}) {
	my $p = $self->{params}->{$obsType}->{pattern};
	if ($self->{params}->{$obsType}->{sl}) {
	    foreach my $sent (@sentences) {
		$self->addStartEndNGrams($sent, $obsType);
	    }
	} else {
	    $self->addNGramsObsType($tokens, $obsType);
	}

    }
}



# internal
sub addNGramsObsType {
    my $self = shift;
    my $tokens = shift;
    my $obsType = shift;

    my $nbTokens = scalar(@$tokens);
    my $p = $self->{params}->{$obsType}->{pattern};
    my $length = $self->{params}->{$obsType}->{length};
    for (my $i=0; $i<=$nbTokens-$length; $i++) {
	my @ngramArray;
	for (my $j=0; $j<scalar(@$p); $j++) {
	    push(@ngramArray, $tokens->[$i+$j]->[ $p->[$j] ]) if ($p->[$j] >= 0);
	}
	my $ngramStr = join($gramSeparator, @ngramArray);
	$self->{logger}->trace("Adding ngram '$ngramStr' for obsType '$obsType'") if ($self->{logger});
	$self->{nbDistinctNGrams}->{$obsType}++ if (!defined($self->{observs}->{$obsType}->{$ngramStr}));
	$self->{observs}->{$obsType}->{$ngramStr}++;
	$self->{nbTotalNGrams}->{$obsType}++;
    }

}



# internal
sub addStartEndNGrams {
    my $self = shift;
    my $tokens = shift;
    my $obsType = shift;
#    $self->{logger}->debug("Adding sentence limits ngrams for obsType '$obsType'") if ($self->{logger});
    my $p = $self->{params}->{$obsType}->{pattern};
    my $length = $self->{params}->{$obsType}->{length};
    my $nbTokens = scalar(@$tokens);
    my @tokensSL = @$tokens;
    my @start3 = ($startLimitToken) x 3;
    my @end3 = ($endLimitToken) x 3;
    for (my $i=1; $i < $length ; $i++) {
	unshift(@tokensSL, \@start3);
	push(@tokensSL, \@end3);
    }
#    $self->{logger}->trace("tokensSL = ".join(" ; ", @tokensSL)) if ($self->{logger}); # annoying, gave up
    $self->addNGramsObsType(\@tokensSL, $obsType);
}


1;
