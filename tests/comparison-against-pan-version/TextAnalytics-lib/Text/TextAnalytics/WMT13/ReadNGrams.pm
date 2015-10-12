package Text::TextAnalytics::WMT13::ReadNGrams;


use strict;
use warnings;
use Carp;
use Log::Log4perl qw(:levels);
use Text::TextAnalytics::Util qw/pickInList pickNAmongSloppy readConfigFile mean discretize selectMFValueCriterion pickInListProbas/;
use Data::Dumper;

use base 'Exporter';
our @EXPORT_OK = qw/readFileToNGramsList sentenceToNGrams tpsPatternStringToBoolean/;

our $VERSION = $Text::TextAnalytics::VERSION;

our $startStopTag = "#";




#
# read a set of N sentences in a file (one sentence by line) and returns a list of N ngrams
# $pattern is a string of chars T/P/S, e.g. PSTP = POS-skip-token-POS
#
sub readFileToNGramsList {
	my $filename = shift;
	my $patternStr  = shift;
	my $addStartStopTags = shift;
	
	my $patternList = tpsPatternStringToBoolean($patternStr);
	open(FILE, "<:encoding(utf-8)", $filename) or confess("Can not open file $filename");
	my @res;
	while (<FILE>) {
		chomp;
		push(@res, sentenceToNGrams($_, $patternList, $addStartStopTags));
	}
	close(FILE);
	return \@res;
	
}


#
# $line is already chomped and is of the form token1/pos1 token2/pos2 ....
# $pattern must be a list of 0/1/undef = token/POS/skip
#
sub sentenceToNGrams {
	my $line = shift;
	my $pattern  = shift;
	my $addStartStopTags = shift;
	
	# transform line to lists
	my @tokens;
	my @posTags;
	my @items = split(/\s+/, $line);
	foreach my $item (@items) {
		my @tokenAndPos = split("/", $item);
		confess "Invalid format in '$item' (expecting <token>/<POS>)" if (scalar(@tokenAndPos)<2);
		if (scalar(@tokenAndPos)>2) {
			my $pos = pop(@tokenAndPos);
			my $token = join("/", @tokenAndPos);
			@tokenAndPos = ($token, $pos);
		}
		push(@tokens, $tokenAndPos[0]); 
		push(@posTags, $tokenAndPos[1]); 
	}
	return tokensAndPOSListsToNGrams(\@tokens, \@posTags, $pattern, $addStartStopTags);
	
}


#
# $tokens and $postTags must be the same length
# $pattern must be a list of 0/1/undef = token/POS/skip
#
sub tokensAndPOSListsToNGrams {
	my $tokens = shift;
	my $posTags = shift;
	my $pattern = shift;
	my $addStartStopTags = shift;
	
	if ($addStartStopTags) {
		$tokens = addStartStopTags($tokens, scalar(@$pattern)-1);
		$posTags = addStartStopTags($posTags, scalar(@$pattern)-1);
	}
	
	my %frequency;
	my $nbNGrams = 0;
	my @windows = ([] , []); # first sublist = token window,  second = POS window (indexes 0/1)
	for (my $i=0; $i<scalar(@$tokens); $i++) {
		if (scalar(@{$windows[0]}) == scalar(@$pattern)) {
		    shift(@{$windows[0]});
		    shift(@{$windows[1]}); # the size of the window never exceeds the size of the pattern
		}
		push(@{$windows[0]}, $tokens->[$i]); # add to window whether it's never been full yet or it has
		push(@{$windows[1]}, $posTags->[$i]);
		if (scalar(@{$windows[0]}) == scalar(@$pattern)) {
		    my $ngram = $windows[$pattern->[0]]->[0]; # warning: assuming the first item in the pattern is not SKIP
	    	for (my $j=1; $j<scalar(@$pattern); $j++) {
				$ngram .= " ".$windows[$pattern->[$j]]->[$j]  if (defined($pattern->[$j]));
	    	}
	    	$nbNGrams++;
			$frequency{$ngram}++;
	    }
	}
	# $nbNGrams not used.
	return \%frequency;
	
}


sub addStartStopTags {
	my $input = shift;
	my $nb = shift;
	my @res;
	push(@res, $startStopTag) foreach (1..$nb); 
	push(@res, @$input);
	push(@res, $startStopTag) foreach (1..$nb); 
	return \@res;
}


sub tpsPatternStringToBoolean {
	my $pattern = shift;
	my @pattern;
	for (my $i=0; $i< length($pattern); $i++) {
	    my $c = lc(substr($pattern,$i,1));
#    	print STDERR "$i: c=$c\n"  if ($debugMode);
 	   if ($c eq "t") {
			push(@pattern, 0);
    	} elsif ($c eq "p") {
			push(@pattern, 1);
    	} elsif ($c eq "s") {
			push(@pattern, undef);
    	} else {
			confess "Error: unknown character $c in token/pos/skip pattern";
    	}
	}
	return \@pattern;
}
	
	
	
1;
