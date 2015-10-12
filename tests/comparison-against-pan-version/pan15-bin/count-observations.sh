#!/bin/bash

# EM 12/02/13

source common-lib.sh
source file-lib.sh


progName="count-observations.sh"
minFreq=0
force=1
verbose=0

function usage {
  echo
  echo "Usage: $progName [options] <lgge id> <obs types list>"
  echo
  echo "  Reads from STDIN a list of files <file> from which observations will"
  echo "  be counted and written to a file <file>.<obs>.count, together with a"
  echo "  file <file>.<obs>.total (in which even discarded observations are"
  echo "  counted)."
  echo
  echo "  Remarks:"
  echo "  - <obs types list> is a lit of types of observations, e.g."   
  echo "    tokens:w2:PTP"
  echo "  - in the case of POS-based observations, the file <file>.POS must" 
  echo "    have been computed (the output file is still <file>.<obs>.count)"
  echo    
  echo "  Options:"
  echo "    -m <min freq> min frequency for an observation to be taken into account."
  echo "    -s skip input <file> if <file>.<obs>.count already exists"
  echo "    -r <ranges> option for WORDLENGTH, if in the list (otherwise ignored)"
  echo "    -f <stop words file> option for STOP<N>, if in the list;"
  echo "      (must be the file for the appropriate language of course)"
  echo "    -v verbose"
  echo
}



while getopts 'hm:svr:f:' option ; do 
    case $option in
	"m" ) minFreq=$OPTARG;;
	"s" ) force=0;;
	"r" ) rangesOpt="$OPTARG";;
	"f" ) stopFile="$OPTARG";;
	"v" ) verbose=1;;
	"h" ) usage
 	    exit 0;;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 2 ]; then
    echo "Error: 2 args expected" 1>&2
    printHelp=1
fi
lang="$1"
obsTypesList="$2"
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi

obsTypes=$(echo "$obsTypesList" | sed 's/:/ /g')

nb=1
while read inputFile; do
    if [ $verbose -ne 0 ]; then
	echo -ne "\rfile $nb: $inputFile"
	nb=$(( $nb + 1 ))
    fi
    for obsType in $obsTypes; do
#	if [ $verbose -ne 0 ]; then
#	    echo -n " $obsType"
#	fi
	output="$inputFile.$obsType.count"
	if [ $force -ne 0 ] || [ ! -s "$output" ]; then
	    params=
	    if [ "$obsType" == "TTR" ]; then # special cases first
		if [ ! -f "$inputFile.tokens.count.total" ]; then # TODO not very nice
		    evalSafe "echo \"$inputFile\" | count-observations.sh -m $minFreq $lang tokens" "$progName,$LINENO: "
		fi
		nbDistinct=$(cut -f 1 "$inputFile.tokens.count.total")
		nbTotal=$(cut -f 2 "$inputFile.tokens.count.total")
		perl -e "print \"TTR\t$nbDistinct\t\".($nbDistinct/$nbTotal).\"\n\";" >"$output"
		echo -e "1\t1" >"$output.total" # probably useless
	    elif [ "$obsType" == "WORDLENGTH" ]; then 
		param=""
		if [ ! -z "$rangesOpt" ]; then
		    param="-c $rangesOpt"
		fi
		evalSafe "count-word-length.pl $param \"$inputFile\" \"$output\"" "$progName,$LINENO: "
 	    elif [ "$obsType" == "MORPHWORD" ]; then 
		evalSafe "count-morph-words.pl \"$inputFile\" \"$output\"" "$progName,$LINENO: "
	    elif [ "${obsType:0:4}" == "STOP" ]; then # STOP<N>
		N=${obsType#STOP}
		if [ -z "$stopFile" ]; then
		    echo "$progName error: must provide stop words file with -f to compute $obsType" 1>&2
		    exit 1
		fi
		evalSafe "echo \"$inputFile\" | count-ngrams-stopwords.pl  -m $minFreq \"$stopFile\" $N  \"$output\" > \"$output.total\"" "$progName,$LINENO: "
	    else
		if [ "${obsType:0:1}" == "P" ] || [ "${obsType:0:1}" == "T" ]; then
		    tokensPOS=1
		    extInput=".POS"
		else
		    tokensPOS=0
		    extInput=""
		    if [ "$obsType" == "tokens" ]; then
			params="$params -ls 1"
		    elif [ "$obsType" == "w2" ]; then
			params="$params -ls 2"
		    elif [ "$obsType" == "w3" ]; then
			params="$params -ls 3"
		    elif [ "$obsType" == "w4" ]; then
			params="$params -ls 4"
		    elif [ "$obsType" == "wYNY" ]; then
			params="$params -ls YNY"
		    elif [ "$obsType" == "c1" ]; then
			params="$params -c 1"
		    elif [ "$obsType" == "c2" ]; then
			params="$params -c 2"
		    elif [ "$obsType" == "c3" ]; then
			params="$params -c 3"
		    elif [ "$obsType" == "c4" ]; then
			params="$params -c 4"
		    elif [ "$obsType" == "c5" ]; then
			params="$params -c 5"
		    else
			echo "$progName: error, unknow observation type code '$obsType'" 1>&2
			exit 6
		    fi
		fi
		input="${inputFile}${extInput}"
#		echo "DEBUG $progName: computing '$output'" 1>&2
		if [ $tokensPOS -eq 0 ]; then 
		    evalSafe "echo \"$input\" | count-ngrams-pattern.pl -m $minFreq $params \"$output\"  > \"$output.total\"" "$progName: "
		else
		    evalSafe "echo \"$input\" | count-POS-tokens-ngrams-combinations.pl -m $minFreq $obsType \"$output\"  > \"$output.total\"" "$progName: "
		fi
	
	    fi
	fi
    done
#    if [ $verbose -ne 0 ]; then
#	echo
#    fi
done
if [ $verbose -ne 0 ]; then
    echo
fi

