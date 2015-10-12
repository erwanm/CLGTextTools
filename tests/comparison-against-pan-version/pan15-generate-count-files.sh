

mydir="comparison-against-pan-version"
obsTypes="tokens:w2:w3:wYNY:c1:c3:c4:P:PP:PPP:PPPP:PTP:TPP:PPT:PT:TP:PST:TSP:TTR:WORDLENGTH:MORPHWORD:STOP1:STOP3:STOP4:STOP5"
minIndivFreqs="1 3 5"
nbStopWords="50 200"
lengthRanges="1-2:3-4:5-6:7-8:9-10:11-99"
pan15binDir="tests/$mydir/pan15-bin"
TAPerlLib="tests/$mydir/TextAnalytics-lib"


if [ $# -ne 2 ]; then
    echo "Usage: <input doc prefix> <output dir>" 1>&2
    echo 1>&2
    echo "  expects file stop-words.N.list for N in '$nbStopWords' in the same dir as the input file." 1>&2
    exit 1
fi
docPrefix="$1"
outputDir="$2"

if [ ! -d "$pan15binDir" ]; then
    echo "Warning: no dir '$pan15binDir', the script seems not to be running from CLGTextTools root dir" 1>&2
    echo "  Either run from CLGTextTools root dir or make the PAN 15 scripts accessible in the PATH env var." 1>&2
else
    export PATH="$PATH:$pan15binDir"
fi

if [ ! -d "$TAPerlLib" ]; then
    echo "Warning: no dir '$TAPerlLib', the script seems not to be running from CLGTextTools root dir" 1>&2
    echo "  Either run from CLGTextTools root dir or make the Text-TextAnalytics lib accessible in the PERL5LIB env var." 1>&2
else
    export PATH="$PATH:$pan15binDir"
    export PERL5LIB="$PERL5LIB:$TAPerlLib"
fi

lang="unused"
[ -d "$outputDir" ] || mkdir "$outputDir"
for minFreq in $minIndivFreqs; do
    for nbStop in $nbStopWords; do
	echo "minFreq=$minFreq, nbStopWords=$nbStop"
	targetDir="$outputDir/$minFreq.$nbStop/"
	[ -d "$targetDir" ] || mkdir "$targetDir"
	targetPrefix="$targetDir/$(basename "$docPrefix")"
	cat "$docPrefix" > "$targetPrefix"
	cat "$docPrefix.POS" >"$targetPrefix.POS"
	tmpErr=$(mktemp)
	{ time echo "$targetPrefix" | count-observations.sh -m $minFreq -r "$lengthRanges" -f "$(dirname "$docPrefix")/stop-words.$nbStop.list" "$lang" "$obsTypes" 2>$tmpErr ; } 2>"$targetDir/time.out"
	if [ ! -z $tmpErr ]; then
	    cat $tmpErr 1>&2
	fi
	rm -f $tmpErr
    done
done
