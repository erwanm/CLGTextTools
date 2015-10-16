
Usage
-----

Source setup.sh from the directory where it is located:
source ./setup.sh



Differences between PAN15 and new version
-----------------------------------------

* CHAR n-grams: bug in the old version, see http://gitlab.scss.tcd.ie/moreaue/CLGTextTools/issues/1
* TTR: no diff in the TTR itself, but the count.total file differ because the old version was setting the total number of ngram as 1 by convention.
* LENGTH: differences only because the name of the classes differ: in pan14 version it was e.g. "class.0" vs. "0" in new version.
* skip-grams "wYNY" (new version "WORD.TST"): big fat bug in pan15 version, the ngrams are wrong, hence the differences.
