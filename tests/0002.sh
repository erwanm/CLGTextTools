#!/bin/bash

# test utf8, especially lowercasing accentuated characters (8 occurrences of "État" + 1 of "États")
source="tests/resources/article-fr-utf8.txt"
obsTypes="WORD.T.lc0.sl0:WORD.T.lc1.sl0"

d=$(mktemp -d)
cat "$source" > "$d/source.txt"
cmd="extract-observations.pl $obsTypes $d/source.txt"
echo "$cmd"
eval "$cmd"
# use erw-bash!
#if [ ! -s "$d/source.txt.WORD.T.lc1.sl0.count" ]; then
    
#fi
