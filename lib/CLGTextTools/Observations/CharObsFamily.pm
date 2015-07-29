package CLGTextTools::Observations::CharObsFamily;

# EM June 2015
# 
#

# * to avoid n-grams which span over two two sentences or documents,
# use two distinct calls to addText: ``addText(sentence1);
# addText(sentence2);``
#
# * similarly, setting ``sentenceLimits`` to 1 will cause the
# adjunction of special characters before and after the wole sequence
# of tokens with which addText is called.
#
# * If the input is a text file with arbitrary line breaks, then
# all the characters must be given in a single call to addText (i.e.
# not line by line).

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Observations::ObsFamily;
use utf8; # IMPORTANT, otherwise string constants are messed up


our @ISA=qw/CLGTextTools::Observations::ObsFamily/;


our $startLimitChar = "§";
our $endLimitChar = "§";
our $lineBreakChar="¤";

sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params);
    return $self;
}


sub addObsType {
    my $self = shift;
    my $obsType = shift;

    if (defined($self->{observs}->{$obsType})) {
	cluckLog($self->{logger}, "Ignoring observation type '$obsType', already initialized.");
    } else {
	$self->{observs}->{$obsType} = {};
	my ($patternStr, $lc, $sl) = ($obsType =~ m/^CHAR\.([CS]+)\.lc([01])\.sl([01])$/);
	confessLog($self->{logger}, "Invalid obs type '$obsType'") if (!length($patternStr) || !length($lc) || !length($sl));
	$self->{logger}->debug("Adding obs type '$obsType': pattern='$patternStr', lc='$lc', sl='$sl'") if ($self->{logger});
	$self->{params}->{$obsType}->{lc} = (defined($lc) && ($lc eq "1"));
	$self->{params}->{$obsType}->{sl} = (defined($sl) && ($sl eq "1"));
	$self->{params}->{$obsType}->{length} = length($patternStr);
	$self->{lc} = $self->{lc} || $self->{params}->{$obsType}->{lc};
	confessLog($self->{logger}, "Invalid type S as first character in pattern '$patternStr'") if (substr($patternStr, 0,1) ne "C");
	my @pattern;
	my $i=0;
	while ($i < length($patternStr)) {
	    my $l=0;
	    while (($i+$l < length($patternStr)) && (substr($patternStr, $i+$l,1) eq "C")) {
		$l++;
	    }
	    push(@pattern, [$i, $l]); # store index and length of every sequence of 'C'
	    $self->{logger}->debug("Pattern '$patternStr': adding char sequence index $i, length $l") if ($self->{logger});
	    $i += $l;
	    while (($i < length($patternStr)) && (substr($patternStr, $i,1) eq "S")) { # go to next C (if any)
		$i++;
	    }
	}
	$self->{params}->{$obsType}->{pattern} = \@pattern;
	$self->{nbNGrams}->{$obsType} = 0;
    }

}





# addText($text)
#
#
sub addText {
    my $self = shift;
    my $text = shift;

    $text =~ s/\n/$lineBreakChar/g;
    my $lcText;
    $lcText = lc($text) if ($self->{lc});
    my @textCase = ($text, $lcText);

    foreach my $obsType (keys %{$self->{observs}}) {
	my $lc =  $self->{params}->{$obsType}->{lc};
	$self->addStartEndNGrams(\@textCase, $obsType) if ($self->{params}->{$obsType}->{sl});
	$self->addNGramsObsType($textCase[$lc], $obsType);
    }
}


sub addNGramsObsType {
    my $self = shift;
    my $text = shift;
    my $obsType = shift;

    my $textLength = length($text);
    my $p = $self->{params}->{$obsType}->{pattern};
    my $length = $self->{params}->{$obsType}->{length};
    for (my $i=0; $i<=$textLength-$length; $i++) {
#	$self->{logger}->trace("i=$i; textLength=$textLength; length=$length") if ($self->{logger});
#	if ($i + $length <= $textLength) {
	    my $ngram="";
	    for (my $j=0; $j<scalar(@$p); $j++) {
		$ngram .=  substr($text, $i + $p->[$j]->[0], $p->[$j]->[1]);
	    }
	    $self->{logger}->trace("Adding ngram '$ngram' for obsType '$obsType'") if ($self->{logger});
	    $self->{observs}->{$obsType}->{$ngram}++;
	    $self->{nbNGrams}->{$obsType}++;
#	}
    }

}



sub addStartEndNGrams {
    my $self = shift;
    my $textCase = shift;
    my $obsType = shift;
    $self->{logger}->debug("Adding sentence limits ngrams for obsType '$obsType'") if ($self->{logger});
    my $p = $self->{params}->{$obsType}->{pattern};
    my $lc =  $self->{params}->{$obsType}->{lc};
    my $length = $self->{params}->{$obsType}->{length};
    my $n = length($textCase->[0]);
    my $startText = "".($startLimitChar x ($length-1)).substr($textCase->[$lc], 0, $length -1);
    my $endText = substr($textCase->[$lc], $n -$length+1 , $length -1).($endLimitChar x ($length-1));
    $self->{logger}->trace("startLimitChar='$startLimitChar' ; startText = '$startText' ; endText = '$endText'") if ($self->{logger});
    $self->addNGramsObsType($startText, $obsType);
    $self->addNGramsObsType($endText, $obsType);
}




1;
