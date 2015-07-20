#!/bin/bash

source="tests/resources/article.txt"
obsTypes="WORD.T.lc0.sl0:WORD.T.lc1.sl0:WORD.TT.lc1.sl0:WORD.TTT.lc1.sl0:WORD.TTT.lc1.sl1:CHAR.CCCC.lc0.sl0:CHAR.CCCC.lc1.sl0:CHAR.CCCC.lc0.sl1:CHAR.CSC.lc0.sl0:WORD.T.lc1.sl0.eng-stop1:WORD.T.lc1.sl0.eng-stop2:WORD.TTT.lc1.sl0.eng-stop1:WORD.TTT.lc1.sl0.eng-stop2"
resources="eng-stop1:tests/resources/english.stop-words;eng-stop2:tests/resources/english.stop-words.50"

if [ -z "$1" ]; then
    d=$(mktemp -d)
else
    dieIfNiSuchDir "$1" "$0,$LINENO: "
    d="$1"
fi
echo "$0. work dir: '$d'"

cat "$source" > "$d/source.txt"
cmd="extract-observations.pl -l TRACE -r \"$resources\" $obsTypes $d/source.txt"
#cmd="extract-observations.pl $obsTypes $d/source.txt"
echo "$cmd"
eval "$cmd"
#rm -rf "$d"
