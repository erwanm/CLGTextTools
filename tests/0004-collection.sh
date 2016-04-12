#!/bin/bash

sourceDir="tests/resources/dataset"
obsTypes="WORD.T.lc0.sl0.mf1:WORD.T.lc1.sl0.mf1:WORD.TT.lc1.sl0.mf1:WORD.TTT.lc1.sl0.mf1:WORD.TTT.lc1.sl1.mf1:CHAR.CCCC.lc0.sl0.mf1:CHAR.CCCC.lc1.sl0.mf1:CHAR.CCCC.lc0.sl1.mf1:CHAR.CSC.lc0.sl0.mf1:POS.TST.sl0.mf1:POS.TTT.sl1.mf1:POS.PPPP.sl1.mf1:POS.LLL.sl1.mf1:POS.TSPL.sl1.mf1:VOCABCLASS.MORPHO.mf1:VOCABCLASS.LENGTH.mf1:VOCABCLASS.LENGTH.2,4,6,9,14.mf1:VOCABCLASS.TTR.mf1"
#obsTypes="WORD.T.lc0.sl0"
#obsTypes="VOCABCLASS.TTR"

if [ -z "$1" ]; then
    d=$(mktemp -d)
else
    dieIfNoSuchDir "$1" "$0,$LINENO: "
    d="$1"
fi
echo "$0. work dir: '$d'"

cp "$sourceDir"/"$prefix"* "$d"
cmd="extract-observations-collection.pl -s doubleLineBreak -l TRACE $obsTypes $sourceDir"
#cmd="extract-observations.pl -l TRACE -r \"$resources\" $obsTypes $d/$prefix"
#cmd="extract-observations.pl -r \"$resources\" $obsTypes $d/$prefix"
echo "$cmd"
eval "$cmd"
#rm -rf "$d"
