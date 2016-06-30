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
cmd="sim-collections-doc-by-doc.pl -R \"$d/\" \"$obsTypes\" \"$d/files1.list\" \"$d/files2.list\""
echo "$cmd"
eval "$cmd"
#rm -rf "$d"


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

cp "$sourceDir"/*.txt "$d"
ls "$d"/*.txt > "$d/files.list"
cmd="ls \"$d\" | count-obs-dataset.sh -i $d/files.list -o '-g -s doubleLineBreak -l TRACE' dutch $obsTypes"
#cmd="extract-observations-collection.pl -s doubleLineBreak -l TRACE $obsTypes $d"
#cmd="extract-observations.pl -l TRACE -r \"$resources\" $obsTypes $d/$prefix"
#cmd="extract-observations.pl -r \"$resources\" $obsTypes $d/$prefix"
#echo "$cmd"

echo "### Pass 1: Generating count files for collection"
time eval "$cmd"
echo

echo "### Time stamp count files (1)"
stat -c '%n %y' "$d"/*.observations/*count* > "$d"/timestamp1.txt 

echo "### Pass 2: Reading count files for collection"
time eval "$cmd"
echo

echo "### Time stamp count files (2)"
stat -c '%n %y' "$d"/*.observations/*count* > "$d"/timestamp2.txt 

echo -n "### Comparing timestamps 1 and 2: "
if cmp "$d"/timestamp1.txt  "$d"/timestamp2.txt; then
   echo "OK"
else
    echo "ERROR"
fi

#rm -rf "$d"
