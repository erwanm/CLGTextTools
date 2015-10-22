#!/bin/bash

sourceDir="tests/resources"
prefix="article.txt"
obsTypes="WORD.T.mf1.lc0.sl0:WORD.T.mf1.lc1.sl0:WORD.TT.mf1.lc1.sl0:WORD.TTT.mf1.lc1.sl0:WORD.TTT.mf1.lc1.sl1:CHAR.CCCC.mf1.lc0.sl0:CHAR.CCCC.mf1.lc1.sl0:CHAR.CCCC.mf1.lc0.sl1:CHAR.CSC.mf1.lc0.sl0:WORD.T.mf1.lc1.sl0.eng-stop1:WORD.T.mf1.lc1.sl0.eng-stop2:WORD.TTT.mf1.lc1.sl0.eng-stop1:WORD.TTT.mf1.lc1.sl0.eng-stop2:POS.TST.mf1.sl0:POS.TTT.mf1.sl1:POS.PPPP.mf1.sl1:POS.LLL.mf1.sl1:POS.TSPL.mf1.sl1:VOCABCLASS.MORPHO.mf1:VOCABCLASS.LENGTH.mf1:VOCABCLASS.LENGTH.2,4,6,9,14.mf1:VOCABCLASS.TTR"
#obsTypes="WORD.T.lc0.sl0"
#obsTypes="VOCABCLASS.TTR"
resources="eng-stop1:tests/resources/english.stop-words;eng-stop2:tests/resources/english.stop-words.50"

if [ -z "$1" ]; then
    d=$(mktemp -d)
else
    dieIfNoSuchDir "$1" "$0,$LINENO: "
    d="$1"
fi
echo "$0. work dir: '$d'"

cp "$sourceDir"/"$prefix"* "$d"
cmd="extract-observations.pl -s doubleLineBreak -l TRACE -r \"$resources\" $obsTypes $d/$prefix"
#cmd="extract-observations.pl -l TRACE -r \"$resources\" $obsTypes $d/$prefix"
#cmd="extract-observations.pl -r \"$resources\" $obsTypes $d/$prefix"
echo "$cmd"
eval "$cmd"
#rm -rf "$d"
