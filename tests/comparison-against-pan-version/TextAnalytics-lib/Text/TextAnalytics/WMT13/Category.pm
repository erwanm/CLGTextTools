package Text::TextAnalytics::WMT13::Category;


use strict;
use warnings;
use Carp;
use Log::Log4perl qw(:levels);
use Text::TextAnalytics::Util qw/writeFileLineByLine/;
use Data::Dumper;
use Text::TextAnalytics::WMT13::ReadNGrams qw/readFileToNGramsList tpsPatternStringToBoolean sentenceToNGrams/;
use File::Basename;

our $VERSION = $Text::TextAnalytics::VERSION;

our $startStopTag = "#";

my @distMethods = qw/binary weightedByNGram cosine/;

#
# filtersParams->{freqThreshold}
# filtersParams->{diffThreshold}
#
sub initCategoryPair {
	my $dirname = shift;
	my $ft = shift;
	my $filtersParams = shift;
	my $addStartStopTag = shift;
	
	confess "Error: directory $dirname does not exist" if (! -d $dirname); 
	foreach my $goodBad (0,1) {
		confess "Error: file $dirname/$goodBad.category" if (! -f "$dirname/$goodBad.category") ;
	} 
	my @dataByNGram;
	my @totalSentences;
	foreach my $goodBad (0,1) {
		my $ngramsList = readFileToNGramsList("$dirname/$goodBad.category", $ft, $addStartStopTag);
		$totalSentences[$goodBad] = scalar(@$ngramsList);
		$dataByNGram[$goodBad] = freqByNgram($ngramsList);
	}
	computeCategoriesStats(\@dataByNGram, \@totalSentences);
	foreach my $goodBad (0,1) {
		mkdir "$dirname/$goodBad" if (! -d  "$dirname/$goodBad");
		mkdir "$dirname/$goodBad/$ft" if (! -d  "$dirname/$goodBad/$ft");
		writeCategoryStatsToFiles("$dirname/$goodBad/$ft", $dataByNGram[$goodBad], $filtersParams);
	}
}


sub freqByNgram {
	my $ngramsList = shift;
	my %data;
	foreach my $sentence (@$ngramsList) {
		foreach my $ngram (keys %$sentence) {
			my $freq = $sentence->{$ngram};
			$data{$ngram}->{$freq}->{absFreq}++;
		}
	}
	return \%data;
}

sub computeCategoriesStats {
	my $dataByNGram = shift;
	my $totalSentences = shift;

	# for all ngrams in 0, compute for both 0 and 1
	foreach my $ngram (keys %{$dataByNGram->[0]}) {
		foreach my $freqSentence (keys %{$dataByNGram->[0]->{$ngram}}) {
			my $this = $dataByNGram->[0]->{$ngram}->{$freqSentence};
			my $other = $dataByNGram->[1]->{$ngram}->{$freqSentence} if (defined($dataByNGram->[1]->{$ngram}) && defined($dataByNGram->[1]->{$ngram}->{$freqSentence})) ;
			$this->{relFreq}  = $this->{absFreq} / $totalSentences->[0];
			$other->{relFreq} = $other->{absFreq} / $totalSentences->[1] if (defined($other));
			my $totalRelFreq  = $this->{relFreq} + ((defined($other)) ? $other->{relFreq} : 0 ) ;
			$this->{proba} = $this->{relFreq} / $totalRelFreq;
			$other->{proba} = $other->{relFreq} / $totalRelFreq if (defined($other));

#			print STDERR "DEBUG ngram='$ngram' ; freqSentence=$freqSentence ; other: absFreq=".$other->{absFreq}." ; other->{relFreq}=".$other->{relFreq}." ; other->{proba}=".$other->{proba}."\n" if (defined($other))
		}
	} 
	
	# for ngrams in 1 which are not in 0
	foreach my $ngram (keys %{$dataByNGram->[1]}) {
		foreach my $freqSentence (keys %{$dataByNGram->[1]->{$ngram}}) {
			if (!defined($dataByNGram->[0]->{$ngram}) || !defined($dataByNGram->[0]->{$ngram}->{$freqSentence})) {
				my $this = $dataByNGram->[1]->{$ngram}->{$freqSentence};
				$this->{relFreq}  = $this->{absFreq} / $totalSentences->[1];
				$this->{proba} = 1;
			}
		}
	} 
	# modified dataByNGram, nothing to return
}


sub writeCategoryStatsToFiles {
	my $dirname = shift;
	my $data  = shift;
	my $filtersParams = shift;

	my %files;
	foreach my $freqFilter (sort { $a <=> $b } @{$filtersParams->{freqThreshold}}) {
	    foreach my $diffFilter (sort { $a <=> $b } @{$filtersParams->{diffThreshold}}) {
		my $f = "$dirname/$freqFilter-$diffFilter.ngrams";
		open(my $fh, ">:encoding(utf-8)", $f) or confess("Can not write to file $f");
		$files{$freqFilter}->{$diffFilter} = $fh;
	    }
	} 	
#	print STDERR "DEBUG WRITE\n";
	foreach my $ngram (keys %$data) {
	    foreach my $freqSentence (keys %{$data->{$ngram}}) {
		my $this  = $data->{$ngram}->{$freqSentence};
#		print STDERR "DEBUG ngram='$ngram' ; freqSentence=$freqSentence ; this: absFreq=".$this->{absFreq}." ; this->{relFreq}=".$this->{relFreq}." ; this->{proba}=".$this->{proba}."\n";
		my ($freqFilter, $diffFiltersData) = each %files;
		foreach my $freqFilter (sort { $a <=> $b } @{$filtersParams->{freqThreshold}}) {
		    if ($this->{absFreq} > $freqFilter) {
			foreach my $diffFilter (sort { $a <=> $b } @{$filtersParams->{diffThreshold}}) {
			    if ($this->{proba} > $diffFilter) {
				my $fh = $files{$freqFilter}->{$diffFilter};
				print $fh "$ngram\t$freqSentence\t".$this->{absFreq}."\t".$this->{relFreq}."\t".$this->{proba}."\n";
			    } else {
				last;
			    }
			}
		    } else  {
			last;
		    }
		}
		
	    }
	}

	foreach my $freqFilter (keys %files) {
	    foreach my $diffFilter (keys %{$files{$freqFilter}}) {
		my $fh = $files{$freqFilter}->{$diffFilter};
		close($fh);
	    }
	} 	

}


sub loadFilteredCategory {
	my $categDir = shift;
	my $goodBad = shift;
	my $ft = shift;
	my $freqThreshold = shift;
	my $diffThreshold  = shift;
	my %res;
	
	my $f = "$categDir/$goodBad/$ft/$freqThreshold-$diffThreshold.ngrams";
	open(FILE, "<:encoding(utf-8)", $f) or confess "Can not open file $f";
	while (<FILE>) {
		chomp;
		my @cols = split("\t", $_);
		confess("Error reading $f: expecting 5 columns, found line $_") if (scalar(@cols != 5));
		my $ngram = shift(@cols);
		my $freqS = shift(@cols);
		my %temp;
		($temp{absFreq}, $temp{relFreq}, $temp{proba}) = @cols;
		$res{$ngram}->{$freqS} = \%temp; 
	}
	close(FILE);
	return \%res; # Remark: if file is empty, hash is empty
}


sub compareFilesToCategory {
	my $categDir = shift;
	my $ft = shift;
	my $addStartStopTags = shift;
	my $testFile = shift;
	my $featuresDestDir = shift;
	my $methods = shift; # list of dist methods to compute; if undef, all methods are computed.
	$methods = \@distMethods if (!defined($methods));
	confess("can not find dir $featuresDestDir") if (! -d $featuresDestDir);
	my $ftBool = tpsPatternStringToBoolean($ft);
	foreach my $goodBad (0,1) {
		mkdir "$featuresDestDir/$goodBad";
		mkdir "$featuresDestDir/$goodBad/$ft";
		my @categFiles = glob("$categDir/$goodBad/$ft/*.ngrams");
		foreach my $categFile (@categFiles) {
			my ($freqThreshold, $diffThreshold) = ($categFile =~ m:([^/]+)-([^/]+).ngrams$:);
			confess("Error: can not parse freq/diff thresholds in categ filename '$categFile'") if (!defined($freqThreshold) || !defined($diffThreshold));
#			print "DEBUG ($freqThreshold, $diffThreshold)\n";
			my $localDestDir = "$featuresDestDir/$goodBad/$ft/";
			mkdir $localDestDir;
			my $categData = loadFilteredCategory($categDir, $goodBad, $ft, $freqThreshold, $diffThreshold);
			my $normCategCos  =  computeNormCategForCosine($categData);
			if (scalar(keys %$categData)>0) {
			    my $features = compareFileToCategory($testFile, $categData, $ftBool, $addStartStopTags, $methods, $normCategCos);
			    foreach my $methodName (@$methods) {
				writeFileLineByLine($features->{$methodName}, "$localDestDir/$freqThreshold-$diffThreshold-$methodName.features");
			    }
			} # else no ngram selected for this categ, hence no features for it (no file created)
		} 
	}
	
}

sub compareFileToCategory {
	my $testFile = shift;
	my $categData = shift;
	my $pattern = shift; # as boolean
	my $addStartStopTags = shift;
	my $methods = shift;
	my $normCategCosine = shift;
	
	my %res;
		
	open(FILE, "<:encoding(utf-8)", $testFile) or confess "Can not open file $testFile";
	while (<FILE>) {
		chomp;
		my $testNGrams = sentenceToNGrams($_, $pattern, $addStartStopTags);
		foreach my $methodName (@$methods) {
		    push(@{$res{$methodName}}, compareSentenceToCategory($testNGrams, $categData, $methodName, $normCategCosine));
		}
	}
	close(FILE);
	return \%res;
}

#
# method = binary, weightedByNGram, cosine
#
sub compareSentenceToCategory {
	my $sentence = shift;
	my $categ = shift;
	my $method = shift;
	my $normCategCosine = shift; # necessary if method is cosine
	
	my $sum=0;
	my $norm;
	foreach my $ngram (keys %$sentence) {
		my $freqSentence = $sentence->{$ngram};
		my $weight = defined($categ->{$ngram}->{$freqSentence}) ? ($categ->{$ngram}->{$freqSentence}->{proba}-0.5)*2 : 0 ;
		if ($method eq "binary") {
			$sum++ if ($weight>0);
			$norm++;
		} elsif ($method eq "weightedByNGram") {
			$sum += $weight;
			$norm++;
		} elsif ($method eq "cosine") {
			$sum += $weight; # = weight x 1
			$norm++;
		} else {
			confess("Invalid distance method '$method'");
		}
	}
	my $res;
	if (($method eq "binary") || ($method eq "weightedByNGram")) {
		$res = $sum / $norm;
	} elsif ($method eq "cosine") {
		$res = $sum / ( $normCategCosine * sqrt($norm) );
	} else {
		confess("Invalid distance method '$method'");
	}
	return $res;
	
}


sub computeNormCategForCosine {
	my $data = shift;
	
	my $sum=0;
	foreach my $ngram (keys %$data) {
	    foreach my $freqSentence (keys %{$data->{$ngram}}) {
	    	$sum += ($data->{$ngram}->{$freqSentence}->{proba})^2;
	    }
	}
	return sqrt($sum);
	
}

1;
