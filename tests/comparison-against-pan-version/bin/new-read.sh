
# remark: stop words version 50 and 200 processed together
obsTypes="WORD.T.lc1.sl0:WORD.TT.lc1.sl0:WORD.TTT.lc1.sl0:WORD.TST.lc1.sl0:CHAR.C.lc0.sl0:CHAR.CCC.lc0.sl0:CHAR.CCCC.lc0.sl0:POS.P.sl0:POS.PP.sl0:POS.PPP.sl0:POS.PPPP.sl0:POS.PTP.sl0:POS.TPP.sl0:POS.PPT.sl0:POS.PT.sl0:POS.TP.sl0:POS.PST.sl0:POS.TSP.sl0:VOCABCLASS.TTR:VOCABCLASS.LENGTH.2,4,6,8,10:VOCABCLASS.MORPHO:WORD.T.lc1.sl0.stop50:WORD.TTT.lc1.sl0.stop50:WORD.TTTT.lc1.sl0.stop50:WORD.TTTTT.lc1.sl0.stop50:WORD.T.lc1.sl0.stop200:WORD.TTT.lc1.sl0.stop200:WORD.TTTT.lc1.sl0.stop200:WORD.TTTTT.lc1.sl0.stop200"
binDir=

minIndivFreqs="1 3 5"
#nbStopWords="50 200"

function writeConfig {
    local minFreq="$1"
    local stopPrefix="$2"
    f=$(mktemp)
    echo "obsTypesList=$obsTypes" >$f
    echo "minFreqObsIndiv=$minFreq" >>$f
    echo "performWordTokenization=1" >>$f
    echo "inputSegmentationFormat=0" >>$f
    echo "wordObsVocabResources=stop50:$stopPrefix.50.list;stop200:$stopPrefix.200.list" >>$f
    echo $f
}


if [ $# -ne 3 ]; then
    echo "Usage: <input doc prefix> <from count file (0|1)> <target dir>" 1>&2
    echo 1>&2
    echo "  expects file stop-words.N.list for N in '$nbStopWords' in the same dir as the input file." 1>&2
    exit 1
fi
docPrefix="$1"
readFromCountFile="$2"
targetDir="$3"

if [ ! -d "$pan15binDir" ]; then
    echo "Warning: no dir '$pan15binDir', the script seems not to be running from CLGTextTools root dir" 1>&2
    echo "  Either run from CLGTextTools root dir or make the PAN 15 scripts accessible in the PATH env var." 1>&2
else
    export PATH="$PATH:$pan15binDir"
fi



[ -d "$targetDir" ] || mkdir "$targetDir"
stopPrefix="$(dirname "$docPrefix")/stop-words"
for minFreq in $minIndivFreqs; do
    configFile=$(writeConfig "$minFreq" "$stopPrefix")
    echo "minFreq=$minFreq; config file=$configFile"
    tmpErr=$(mktemp)
    { time load-ngrams-counts.pl "$configFile" "$docPrefix" 2>$tmpErr ; } 2>"$targetDir/time.$minFreq.out"
    cat $tmpErr 1>&2
#    rm -f $tmpErr $configFile
 #   done
done
