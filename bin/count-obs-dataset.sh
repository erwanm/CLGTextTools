#!/bin/bash

# EM April 16

source common-lib.sh
source file-lib.sh

currentDir=$(pwd)
progName="count-obs-dataset.sh"
force=0
extractObsOptions=""
readFromFile=""



function usage {
  echo
  echo "Usage: $progName [options] <language> <obs types list>"
  echo
  echo "  Prepares observations count files for a list of documents read from"
  echo "  <STDIN> (filenames), including generating TreeTagger POS output if"
  echo "  needed (depending on whether POS obs types are used)."
  echo "  <obs types list> is the list of obs types separated by colons ':'."
  echo
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -f force overwriting if the output file already exists (default: do"
  echo "       nothing if the non-empty output file exists)"
  echo "    -o <options for extract-observations-collection.pl> used to transmit"
  echo "       options to the script (e.g. '-r <resources opts>'). Use quotes to"
  echo "       protect spaces."
  echo "    -i <list file> read the list of documents from this file rather than from"
  echo "       <STDIN>."
  echo
}



function tokAndPOS {
    local language="$1"
    local filesList="$2"

    cat "$filesList" | while read f; do
	if [ $force -ne 0 ] || [ ! -s "$f.POS" ]; then
	    evalSafe "tree-tagger-tokenizer-wrapper.sh $language <\"$f\" >\"$f.tok\""  "$progName: "
	    evalSafe "tree-tagger-POS-wrapper.sh $language <\"$f.tok\" >\"$f.POS\""  "$progName: "
	fi
    done
    if [ $? -ne 0 ]; then
	echo "$progName: an error happened in 'tokAndPOS', aborting." 1>&2
	exit 5
    fi
}





while getopts 'hfo:i:' option ; do 
    case $option in
	"f" ) force=1;;
	"o" ) extractObsOptions="$OPTARG";;
	"i" ) readFromFile="$OPTARG";;
	"h" ) usage
 	      exit 0;;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 2 ]; then
    echo "Error: expecting 2 args." 1>&2
    printHelp=1
fi
lang="$1"
obsTypesList="$2"

if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi


if [ -z "$readFromFile" ]; then
    listFile=$(mktemp "$progName.XXXXXXXX")
    while read inputDocFile; do
	echo "$inputDocFile"
    done > "$listFile"
else
    listFile="$readFromFile"
fi

requiresPOSTags=$(echo "$obsTypesList" | grep ":POS.")
if [ -z "$requiresPOSTags" ]; then # check if first obs type
    requiresPOSTags=$(echo "$obsTypesList" | grep "^POS.")
fi
if [ -z "$requiresPOSTags" ]; then
    echo "$progName: no TreeTagger tokenization/POS tagging needed"
else
    echo "$progName: tokenization and POS tagging"
    tokAndPOS "$lang" "$listFile"
fi

if [ $force -ne 0 ]; then
    extractObsOptions="-f $extractObsOptions"
fi
echo "$progName: generating count files"
evalSafe "extract-observations-collection.pl $extractObsOptions \"$obsTypesList\" \"$listFile\"" "$progName,$LINENO: "


if [ -z "$readFromFile" ]; then  # temporary list file
    rm -f "$listFile"
fi




