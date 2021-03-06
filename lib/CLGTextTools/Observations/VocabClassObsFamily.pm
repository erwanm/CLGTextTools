package CLGTextTools::Observations::VocabClassObsFamily;

#twdoc 
#
# Obs family class for "vocabulary-based" observations: every word is replaced with a category depending on some features of the word
#
# * morphology
# * length
# * Type-token ratio (special case, only one obs)
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
use CLGTextTools::Commons qw/readTextFileLines arrayToHash assignDefaultAndWarnIfUndef/;
use CLGTextTools::Observations::ObsFamily;
use Data::Dumper::Simple;

our @ISA=qw/CLGTextTools::Observations::ObsFamily/;


our $gramSeparator = " ";
our $startLimitToken = "#START_SENTENCE#";
our $endLimitToken = "#END_SENTENCE#";
our $unknownToken = "_";


#twdoc new($class, $params)
#
# See parent. Other parameters:
#
# * ``lengthClasses`` A hash of the form ``$params->{lengthClasses}->{classId} = length class``, where a length class is described as ``<maxLength_1:maxLength_2:...>``. For instance '3:6:11' means that:
# ** length 1 to 3 are labelled as class 0,
# ** length 4 to 6 as class 1,
# ** length 7 to 11 as class 2,
# ** and any higher length as class 3.
#
#/twdoc

sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params, __PACKAGE__);
    $self->{wordTokenization} = assignDefaultAndWarnIfUndef("wordTokenization", $params->{wordTokenization}, 1, $self->{logger});
    if (defined($params->{lengthClasses})) {
	$self->{logger}->debug("word length classes parameter found: ".$params->{lengthClasses}) if ($self->{logger});
	$self->{logger}->trace("word length classes hash content = ".Dumper($params->{lengthClasses})) if ($self->{logger});
	foreach my $classId (keys %{$params->{lengthClasses}}) {
	    $self->{logger}->trace("calling addLengthclass for key:'$classId', value:'".$params->{lengthClasses}->{$classId}."'") if ($self->{logger});
	    my @lengthClass = split(":", $params->{lengthClasses}->{$classId});
	    $self->{lengthClasses}->{$classId} = \@lengthClass;
	}
    }
    return $self;
}


#twdoc addObsType($self, $obsType)
#
# Format a VocabClass obs type:
#
# * ``VOCABCLASS.MORPHO``: replaces every word with a category among: allLowerCase, allUpperCase, firstUpperCase, mixedCase, number, punct, misc
# * ``VOCABCLASS.TTR``: Type token ratio
# * ``VOCABCLASS.LENGTH[:<classId>]``: see ``new``
#
#/twdoc
sub addObsType {
    my $self = shift;
    my $obsType = shift;

    if (defined($self->{observs}->{$obsType})) {
	cluckLog($self->{logger}, "Ignoring observation type '$obsType', already initialized.");
    } else {
	$self->{observs}->{$obsType} = {};
	if ($obsType =~ m/^VOCABCLASS\.MORPHO$/) {
	    $self->{params}->{$obsType}->{type} = "morpho";
	    $self->{logger}->debug("Adding obs type '$obsType': morpho") if ($self->{logger});
	} elsif ($obsType =~ m/^VOCABCLASS\.PUNCT$/) {
	    $self->{params}->{$obsType}->{type} = "punct";
	    $self->{logger}->debug("Adding obs type '$obsType': punct") if ($self->{logger});
	} elsif ($obsType =~ m/^VOCABCLASS\.TTR$/) { # no min freq 
	    $self->{params}->{$obsType}->{type} = "TTR";
	    $self->{logger}->debug("Adding obs type '$obsType': TTR") if ($self->{logger});
	} elsif ($obsType =~ m/^VOCABCLASS\.LENGTH/) {
	    my ($classId) = ($obsType =~ m/^VOCABCLASS\.LENGTH(?:\.(.+))?$/); # $classId can be undefined (default class = simple word length)
	    $self->{params}->{$obsType}->{type} = "length";
	    if (defined($classId)) {
		my @classes = split(",", $classId) ;
		$self->{params}->{$obsType}->{lengthClasses} = \@classes;
	    }
	    $self->{logger}->debug("Adding obs type '$obsType': length, classId='".(defined($classId)?$classId:"undef")."'") if ($self->{logger});
	} else {
	    confessLog($self->{logger}, "Invalid obs type '$obsType'");
	}
	$self->{nbDistinctNGrams}->{$obsType} = 0;
	$self->{nbTotalNGrams}->{$obsType} = 0;
    }

}



#twdoc addText($self, $text)
#
# see parent
#
#/twdoc
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
    my @tokens = split(/\s+/, $text);
    my $nbTokens = scalar(@tokens);
    $self->{logger}->debug("Adding text: $nbTokens tokens.") if ($self->{logger});

    my %bag;
    for (my $i = 0; $i < $nbTokens; $i++) {
	$bag{$tokens[$i]}++;
    }

    foreach my $obsType (keys %{$self->{observs}}) {
	my $type = $self->{params}->{$obsType}->{type};
	if ($type eq "TTR") {
	    my %lcBag; # standardizing case (remark: not the most efficient way, but this way avoids complications with different cases above)
	    foreach my $word (keys %bag) {
		$lcBag{lc($word)} = 1; # the actual number does not matter
	    }
	    $self->{observs}->{$obsType}->{TTR} = scalar(keys %lcBag); # = nb distinct tokens
	} else {
	    my $lengthClasses = $self->{params}->{$obsType}->{lengthClasses} if ($type eq "length");
	    foreach my $word (keys %bag) {
		my $class;
		if ($type eq "morpho") {
		    $class = getMorphClass($word);
		} elsif ($type eq "punct") {
		    $class = getPunctClass($word);
		} elsif ($type eq "length") {
		    my $l = length($word); # default class (no length classes supplied)
		    if (defined($lengthClasses)) {
			$class = 0;
			while ( ($class < scalar(@$lengthClasses)) && ($lengthClasses->[$class] < $l) ) {
			    $class++;
			}
		    } else {
			$class = $l;
		    }
		} else {
		    confessLog($self->{logger}, "BUG");
		}
		$self->{logger}->trace("Adding $bag{$word} occurrences of class '$class' for token '$word' (obsType '$obsType')") if ($self->{logger});
		$self->{observs}->{$obsType}->{$class} += $bag{$word};
	    }
	}
	$self->{nbDistinctNGrams}->{$obsType} = scalar(keys %{$self->{observs}->{$obsType}});
	$self->{nbTotalNGrams}->{$obsType} += $nbTokens;
    }
}


# 
sub getMorphClass {
    my $token=  shift;
    if ($token =~ m/^\p{Alpha}+$/) { # all alpha
        if ($token =~ m/^\p{Lowercase}+$/) { # all lower
            return "allLowerCase";
        } elsif ($token =~ m/^\p{Uppercase}\p{Lowercase}*$/) { # first upper
            return "firstUpperCase";
        } elsif ($token =~ m/^\p{Uppercase}+$/) { # all upper
            return "allUpperCase";
        } else {
            return "mixedCase";
        }
    } elsif ($token =~ m/^[-+]?[0-9]*\.?[0-9]+$/) {
        return "number";
    } elsif ($token =~ m/^[!?\.,;:"'()[\]]+$/) {
        return "punct";
    } else {
        return "misc";
    }

}


 
sub getPunctClass {
    my $token=  shift;
    if ($token =~ m/^\p{Alnum}+$/) {
	return "ALPHANUM";
    } else {
        return "$token";
    }

}




1;
