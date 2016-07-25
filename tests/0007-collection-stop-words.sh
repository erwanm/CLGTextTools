#!/bin/bash

sourceDir="tests/resources/dataset"
obsTypes="WORD.T.lc1.sl0.eng-stop1.mf1:WORD.T.lc1.sl0.eng-stop2.mf1:WORD.TTT.lc1.sl0.eng-stop1.mf1:WORD.TTT.lc1.sl0.eng-stop2.mf1"
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

cp "$sourceDir"/*.txt "$d"
ls "$d"/*.txt > "$d/files.list"
cmd="ls \"$d\" | count-obs-dataset.sh -i $d/files.list -o '-g -s doubleLineBreak -r \"$resources\" -l TRACE' dutch $obsTypes"
#cmd="extract-observations-collection.pl -s doubleLineBreak -l TRACE $obsTypes $d"
#cmd="extract-observations.pl -l TRACE -r \"$resources\" $obsTypes $d/$prefix"
#cmd="extract-observations.pl -r \"$resources\" $obsTypes $d/$prefix"
echo "$cmd"
eval "$cmd"
#rm -rf "$d"
