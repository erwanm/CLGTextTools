
obsTypesPan="tokens:w2:w3:wYNY:c1:c3:c4:P:PP:PPP:PPPP:PTP:TPP:PPT:PT:TP:PST:TSP:TTR:WORDLENGTH:MORPHWORD"
# remark: stop words version 50 and 200 processed together
obsTypesNew="WORD.T.lc1.sl0:WORD.TT.lc1.sl0:WORD.TTT.lc1.sl0:WORD.TST.lc1.sl0:CHAR.C.lc0.sl0:CHAR.CCC.lc0.sl0:CHAR.CCCC.lc0.sl0:POS.P.sl0:POS.PP.sl0:POS.PPP.sl0:POS.PPPP.sl0:POS.PTP.sl0:POS.TPP.sl0:POS.PPT.sl0:POS.PT.sl0:POS.TP.sl0:POS.PST.sl0:POS.TSP.sl0:VOCABCLASS.TTR:VOCABCLASS.LENGTH.2,4,6,8,10:VOCABCLASS.MORPHO"
stopTypesN="STOP1:WORD.T.lc1.sl0.stop STOP3:WORD.TTT.lc1.sl0.stop STOP4:WORD.TTTT.lc1.sl0.stop STOP5:WORD.TTTTT.lc1.sl0.stop"

minIndivFreqs="1 3 5"
nbStopWords="50 200"


function doDiff {
    fPan="$1"
    fNew="$2"
    fBase="$3"
    targetDir="$4"
    obsPan="$5"
    obsNew="$6"

#    echo "fPan=$fPan ; fNew=$fNew ; fBase=$fBase"
    panCol=$(mktemp)
    newCol=$(mktemp)
    cut -f 1-2 "$fPan" >"$panCol"
    cut -f 1-2 "$fNew" >"$newCol"
    diff  "$panCol" "$newCol" >"$targetDir/$fBase.$obsPan.$obsNew.count.diff"
    rm -f "$panCol" "$newCol"
    [ -s "$targetDir/$fBase.$obsPan.$obsNew.count.diff" ] || rm -f "$targetDir/$fBase.$obsPan.$obsNew.count.diff"
    diff "$fPan.total" "$fNew.total" >"$targetDir/$fBase.$obsPan.$obsNew.count.total.diff"
    [ -s "$targetDir/$fBase.$obsPan.$obsNew.count.total.diff" ] || rm -f "$targetDir/$fBase.$obsPan.$obsNew.count.total.diff"
}


if [ $# -ne 3 ]; then
    echo "Usage: <<output dir pan> <<output dir new> <outputDir>" 1>&2
    echo 1>&2
    exit 1
fi
panDir="$1"
newDir="$2"
outputDir="$3"

[ -d "$outputDir" ] || mkdir "$outputDir"
nbObsTypesPan=$(echo "$obsTypesPan" | tr ':' ' ' | wc -w)
nbObsTypesNew=$(echo "$obsTypesNew" | tr ':' ' ' | wc -w)
if [ $nbObsTypesPan -ne $nbObsTypesNew ]; then
    echo "Bug: different number of obs types between the two versions" 1>&2
    exit 2
fi
anyStop=$(echo "$nbStopWords" | cut -d " " -f 1)
for minFreq in $minIndivFreqs; do
    echo "minFreq=$minFreq"
    targetDir="$outputDir/$minFreq"
    [ -d "$targetDir" ] || mkdir "$targetDir"
    for obsTypeNo in $(seq 1 $nbObsTypesPan); do
	obsPan=$(echo "$obsTypesPan" | cut -d ":" -f $obsTypeNo)
	obsNew=$(echo "$obsTypesNew" | cut -d ":" -f $obsTypeNo)
#	echo "obsTypes = $obsPan ; $obsNew"
	for fPan in "$panDir/$minFreq.$anyStop"/*.$obsPan.count; do 
	    fBase=$(basename "${fPan%.$obsPan.count}")
	    fNew="$newDir/$minFreq/$fBase.$obsNew.count"
	    doDiff "$fPan" "$fNew" "$fBase" "$targetDir" "$obsPan" "$obsNew"
	done
    done
    for stopType in $stopTypesN; do
	panType=${stopType%:*}
	newType=${stopType#*:}
	for nbStop in $nbStopWords; do
	    obsPan="$panType"
	    obsNew="${newType}${nbStop}"
	    for fPan in "$panDir/$minFreq.$nbStop"/*.$obsPan.count; do 
		fBase=$(basename "${fPan%.$obsPan.count}")
		fNew="$newDir/$minFreq/$fBase.$obsNew.count"
		doDiff "$fPan" "$fNew" "$fBase" "$targetDir" "$obsPan" "$obsNew"
	    done
	done
    done
done
