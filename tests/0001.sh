#!/bin/bash

sourceDir="tests/resources"
prefix="article.txt"
obsTypes="WORD.T.lc0.sl0:WORD.T.lc1.sl0:WORD.TT.lc1.sl0:WORD.TTT.lc1.sl0:WORD.TTT.lc1.sl1:CHAR.CCCC.lc0.sl0:CHAR.CCCC.lc1.sl0:CHAR.CCCC.lc0.sl1:CHAR.CSC.lc0.sl0:WORD.T.lc1.sl0.eng-stop1:WORD.T.lc1.sl0.eng-stop2:WORD.TTT.lc1.sl0.eng-stop1:WORD.TTT.lc1.sl0.eng-stop2:POS.TST.sl0:POS.TTT.sl1:POS.PPPP.sl1:POS.LLL.sl1:POS.TSPL.sl1:VOCABCLASS.MORPHO:VOCABCLASS.LENGTH:VOCABCLASS.LENGTH.2,4,6,9,14:VOCABCLASS.TTR"
#obsTypes="VOCABCLASS.TTR"
resources="eng-stop1:tests/resources/english.stop-words;eng-stop2:tests/resources/english.stop-words.50"

if [ -z "$1" ]; then
    d=$(mktemp -d)
else
    dieIfNiSuchDir "$1" "$0,$LINENO: "
    d="$1"
fi
echo "$0. work dir: '$d'"

cp "$sourceDir"/"$prefix"* "$d"
cmd="extract-observations.pl -l TRACE -r \"$resources\" $obsTypes $d/$prefix"
#cmd="extract-observations.pl -r \"$resources\" $obsTypes $d/$prefix"
echo "$cmd"
eval "$cmd"
#rm -rf "$d"
