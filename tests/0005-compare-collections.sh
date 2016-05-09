#!/bin/bash

sourceDir="tests/resources/dataset"
obsTypes="WORD.T.lc0.sl0.mf1:WORD.T.lc1.sl1.mf1:WORD.TT.lc1.sl0.mf1:WORD.TTT.lc1.sl0.mf1:WORD.TTT.lc1.sl1.mf1:CHAR.CCCC.lc0.sl0.mf1:CHAR.CCCC.lc1.sl0.mf1:CHAR.CCCC.lc0.sl1.mf1:CHAR.CSC.lc0.sl0.mf1:VOCABCLASS.MORPHO.mf1:VOCABCLASS.LENGTH.mf1:VOCABCLASS.LENGTH.2,4,6,9,14.mf1:VOCABCLASS.TTR.mf1"
#obsTypes="WORD.T.lc0.sl0"
#obsTypes="VOCABCLASS.TTR"

if [ -z "$1" ]; then
    d=$(mktemp -d)
else
    dieIfNoSuchDir "$1" "$0,$LINENO: "
    d="$1"
fi
echo "$0. work dir: '$d'"

cp "$sourceDir"/*.txt "$d"
ls "$d"/*.txt | head -n 4 > "$d/files1.list"
ls "$d"/*.txt | tail -n 4 > "$d/files2.list"
cmd="sim-collections-doc-by-doc.pl \"$obsTypes\" \"$d/files1.list\" \"$d/files2.list\""
echo "$cmd"
eval "$cmd"
#rm -rf "$d"
