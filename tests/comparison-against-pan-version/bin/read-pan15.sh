
obsTypes="tokens:w2:w3:wYNY:c1:c3:c4:P:PP:PPP:PPPP:PTP:TPP:PPT:PT:TP:PST:TSP:TTR:WORDLENGTH:MORPHWORD:STOP1:STOP3:STOP4:STOP5"

minIndivFreqs="1 3 5"
nbStopWords="50 200"

function writeConfig {
    local minFreq="$1"
#    local stopPrefix="$2"
    f=$(mktemp)
    echo "obsTypesList=$obsTypes" >$f
    echo "minFreqObsIndiv=$minFreq" >>$f
#    echo "performWordTokenization=1" >>$f
#    echo "inputSegmentationFormat=0" >>$f
#    echo "wordObsVocabResources=stop50:$stopPrefix.50.list;stop200:$stopPrefix.200.list" >>$f
    echo $f
}


if [ $# -ne 3 ]; then
    echo "Usage: <input doc prefix> <input dir> <target dir>" 1>&2
    echo 1>&2
    echo "  expects file stop-words.N.list for N in '$nbStopWords' in the same dir as the input file." 1>&2
    exit 1
fi
docPrefix="$1"
inputDir="$2"
targetDir="$3"



[ -d "$targetDir" ] || mkdir "$targetDir"
for minFreq in $minIndivFreqs; do
    for nbStop in $nbStopWords; do
	countPrefix="$inputDir/$minFreq.$nbStop/$(basename "$docPrefix")"
	configFile=$(writeConfig "$minFreq")
	echo "minFreq=$minFreq; nbStop=$nbStop; config file=$configFile"
	tmpErr=$(mktemp)
	{ time load-ngrams-counts.pl -c "$configFile" "$countPrefix" 2>$tmpErr ; } 2>"$targetDir/time.$minFreq.$nbStop.out"
	cat $tmpErr 1>&2
	rm -f $tmpErr $configFile
    done
done

