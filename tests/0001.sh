#!/bin/bash

source="tests/resources/article.txt"
obsTypes="WORD.T.lc0.sl0:WORD.T.lc1.sl0:WORD.TT.lc1.sl0:WORD.TTT.lc1.sl0:WORD.TTT.lc1.sl1:CHAR.CCCC.lc0.sl0:CHAR.CCCC.lc0.sl1"

f=$(mktemp)
cat "$source" > "$f"
cmd="extract-observations.pl $obsTypes $f"
echo "$cmd"
eval "$cmd"

