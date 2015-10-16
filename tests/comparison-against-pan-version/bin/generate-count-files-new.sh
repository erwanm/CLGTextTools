
#obsTypes="tokens:w2:w3:wYNY:c1:c3:c4:P:PP:PPP:PPPP:PTP:TPP:PPT:PT:TP:PST:TSP:TTR:WORDLENGTH:MORPHWORD:STOP1:STOP3:STOP4:STOP5"

# remark: stop words version 50 and 200 processed together
obsTypes="WORD.T.lc1.sl0:WORD.TT.lc1.sl0:WORD.TTT.lc1.sl0:WORD.TST.lc1.sl0:CHAR.C.lc0.sl0:CHAR.CCC.lc0.sl0:CHAR.CCCC.lc0.sl0:POS.P.sl0:POS.PP.sl0:POS.PPP.sl0:POS.PPPP.sl0:POS.PTP.sl0:POS.TPP.sl0:POS.PPT.sl0:POS.PT.sl0:POS.TP.sl0:POS.PST.sl0:POS.TSP.sl0:VOCABCLASS.TTR:VOCABCLASS.LENGTH.2,4,6,8,10:VOCABCLASS.MORPHO:WORD.T.lc1.sl0.stop50:WORD.TTT.lc1.sl0.stop50:WORD.TTTT.lc1.sl0.stop50:WORD.TTTTT.lc1.sl0.stop50:WORD.T.lc1.sl0.stop200:WORD.TTT.lc1.sl0.stop200:WORD.TTTT.lc1.sl0.stop200:WORD.TTTTT.lc1.sl0.stop200"

minIndivFreqs="1 3 5"
nbStopWords="50 200"


if [ $# -ne 2 ]; then
    echo "Usage: <input doc prefix> <output dir>" 1>&2
    echo 1>&2
    echo "  expects file stop-words.N.list for N in '$nbStopWords' in the same dir as the input file." 1>&2
    exit 1
fi
docPrefix="$1"
outputDir="$2"


[ -d "$outputDir" ] || mkdir "$outputDir"
stopPrefix="$(dirname "$docPrefix")/stop-words"
for minFreq in $minIndivFreqs; do
#    for nbStop in $nbStopWords; do
	echo "minFreq=$minFreq"
	targetDir="$outputDir/$minFreq/"
	[ -d "$targetDir" ] || mkdir "$targetDir"
	targetPrefix="$targetDir/$(basename "$docPrefix")"
	cat "$docPrefix" > "$targetPrefix"
	cat "$docPrefix.POS" >"$targetPrefix.POS"

	tmpErr=$(mktemp)
	{ time extract-observations.pl -m $minFreq -r "stop50:$stopPrefix.50.list;stop200:$stopPrefix.200.list" "$obsTypes" "$targetPrefix" 2>$tmpErr ; } 2>"$targetDir/time.out"
	cat "$tmpErr" 1>&2
	rm -f $tmpErr
 #   done
done
