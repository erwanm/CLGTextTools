#!/bin/bash

source common-lib.sh
source file-lib.sh

# test utf8, especially lowercasing accentuated characters (8 occurrences of "État" + 1 of "États")

source="tests/resources/article-fr-utf8.txt"
obsTypes="WORD.T.mf1.lc0.sl0:WORD.T.mf1.lc1.sl0"

if [ -z "$1" ]; then
    d=$(mktemp -d)
else
    dieIfNiSuchDir "$1" "$0,$LINENO: "
    d="$1"
fi
echo "$0. work dir: '$d'"

function sumFreqEtat {
    file="$1"
    nbs=$(grep -i "^état\s" "$file" | cut -f 2)
    total=0
    for n in $nbs; do
	total=$(( $total + $n ))
    done
    echo "$total"
}


cat "$source" > "$d/source.txt"
cmd="extract-observations.pl $obsTypes $d/source.txt"
echo "$cmd"
evalSafe "$cmd" "$0,$LINENO: "
dieIfNoSuchFile "$d/source.txt.WORD.T.mf1.lc1.sl0.count" "$0,$LINENO: "
nb1=$(sumFreqEtat  "$d"/source.txt.WORD.T.mf1.lc0.sl0.count)
nb2=$(sumFreqEtat  "$d"/source.txt.WORD.T.mf1.lc1.sl0.count)
if [ $nb1 -ne $nb2 ]; then
    echo "$0: test failed" 1>&2
    exit 1
fi
#rm -rf "$d"
