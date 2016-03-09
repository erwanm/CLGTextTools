#!/bin/bash

# EM Jan 16


progName=$(basename "$BASH_SOURCE")

printAsParamValue=""

patternsWord="T TT TTT"
lcWord="1"
slWord="1"
patternsStopWords="TTT TTTT TTTTT TTTTTT"
lcStopWords="1"
slStopWords="1"
patternsChar="CC CCC CCCC"
lcChar="0"
slChar="1"
patternsPOS="P PP PPP PPPP L LSL LSSL TST PSP TP PT TTP PTT TPP PPT PPST TSPP"
slPOS="1"
patternsVocabClass="MORPHO TTR LENGTH.2,4,6,9,14"

function usage {
  echo
  echo "Usage: $progName [options] <min frequencies> <stop-words ids>"
  echo
  echo "  prints a standard list of obs types to STDOUT."
  echo "  <min frequencies> and <stop-words ids> contain a list of values"
  echo "  separated by spaces (use quotes if several values)."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -p <value> print as config parameters: 'obsType.<obs type>=<value>'"
  echo
}


function printObsType {
    obsType="$1"
    if [ -z "$printAsParamValue" ]; then
	echo "$obsType"
    else
	echo "obsType.$obsType=$printAsParamValue"
    fi
}


OPTIND=1
while getopts 'hp:' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"p" ) printAsParamValue="$OPTARG";;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -lt 1 ]; then
    echo "Error: expecting at least 1 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi

minFreqs="$1"
stopWordsIds="$2"


for minFreq in $minFreqs; do
    for p in $patternsWord; do
	for lc in $lcWord; do
	    for sl in $slWord; do
		printObsType "WORD.$p.lc$lc.sl$sl.mf$minFreq"
	    done
	done
    done

    for swId in $stopWordsIds; do
	for p in $patternsStopWords; do
	    for lc in $lcStopWords; do
		for sl in $slStopWords; do
		    printObsType "WORD.$p.lc$lc.sl$sl.$swId.mf$minFreq"
		done
	    done
	done
    done

    for p in $patternsChar; do
	for lc in $lcChar; do
	    for sl in $slChar; do
		printObsType "CHAR.$p.lc$lc.sl$sl.mf$minFreq"
	    done
	done
    done

    for p in $patternsPOS; do
	for sl in $slPOS; do
	    printObsType "POS.$p.sl$sl.mf$minFreq"
	done
    done

    for p in $patternsVocabClass; do
	printObsType "VOCABCLASS.$p.mf$minFreq"
    done
done
