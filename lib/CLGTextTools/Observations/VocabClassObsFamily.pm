package CLGTextTools::Observations::VocabClassObsFamily;

# EM July 2015
# 
#


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
our $unknownToken = "_";


#
# A length class is described as <maxLength_1:maxLength_2:...>. For instance '3:6:11' means that:
# * length 1 to 3 are labelled as class 0,
# * length 4 to 6 as class 1,
# * length 7 to 11 as class 2,
# * and any higher length as class 3.
#


sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params);
    $self->{wordTokenization} = 1 unless (defined($params->{wordTokenization}) && ($params->{wordTokenization} == 0));
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
	} elsif ($obsType =~ m/^VOCABCLASS\.TTR$/) {
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
	$self->{nbNGrams}->{$obsType} = 0;
    }

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

    my %bag;
    for (my $i = 0; $i < $nbTokens; $i++) {
	$bag{$tokens[$i]}++;
    }

    foreach my $obsType (keys %{$self->{observs}}) {
	my $type = $self->{params}->{$obsType}->{type};
	if ($type eq "TTR") { # remark: case not standardized, which would be better in this case
	    $self->{observs}->{$obsType}->{TTR} = scalar(keys %bag); # = nb distinct tokens
	} else {
	    my $lengthClasses = $self->{params}->{$obsType}->{lengthClasses} if ($type eq "length");
	    foreach my $word (keys %bag) {
		my $class;
		if ($type eq "morpho") {
		    $class = getMorphClass($word);
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
	$self->{nbNGrams}->{$obsType} = $nbTokens;
    }
}


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




1;
