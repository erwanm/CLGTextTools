#!/bin/bash

# EM April 15

source common-lib.sh
source file-lib.sh

progName=$(basename "$BASH_SOURCE")

apiKeyFile="$HOME/.my-google-API-key.txt"
if [ ! -f  "$apiKeyFile" ]; then
    echo "Error: file $HOME/.my-google-API-key.txt not found." 1>&2
    exit 1
fi
myAPIKey=$(cat "$apiKeyFile")

minNbWordsDoc=100
minNbWordsParag=25

function usage {
  echo
  echo "Usage: $progName [options] <language> <query> <nb docs> <output prefix>"
  echo
  echo "  Uses google-query.sh to extract documents from the web, then strips any HTML"
  echo "  tags and preprocesses the documents to make sure that they contain enough"
  echo "  text content. Keeps requiring google results as long as the documents don't"
  echo "  contain enough text, or if Google doesn't find anymore result."
  echo "  Use '+' as separator if multiple words in the query. Resulting documents are"
  echo "  written as individual <output prefix><NNN>.txt files, where <NNN> is the"
  echo "  number of the link in google search results."
  echo
  echo "  Remark: max 100 queries a day with free account, and  the results might contain "
  echo "  commercial links, depending on the CSE definition."
  echo "  IMPORTANT: a file $HOME/.my-google-API-key.txt must exist and contain a valid"
  echo "             Google API key."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo " -p <min nb words>: after cleaning the HTML, remove any paragraph"
  echo "     contanining less than N words. A paragraph is defined as any"
  echo "     sequence of non-empty lines. Default: $minNbWordsParag."
  echo "     Remark: this is to minimize the amount of single words part of"
  echo "     the web page interface and such (and maximize real text content)."
  echo " -s <min size in words> minimum size to take a document into account;"
  echo "    default: $miNbWordsDoc."
  echo
}



OPTIND=1
while getopts 'hp:s:' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"p" ) minNbWordsParag="$OPTARG";;
	"s" )  minNbWordsDoc="$OPTARG";;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 4 ]; then
    echo "Error: expecting 4 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi
lang="$1"
query="$2"
nbDocs="$3"
outputPrefix="$4"

index=1
echo -n "Google query '$query'; index and progress:"
while [ $nbDocs -gt 0 ]; do
    echo -n "   $index (need $nbDocs more)"
    google-query.sh -l $lang -n $index "$query" "$outputPrefix" "$myAPIKey"
    newResults=0
    for f in $outputPrefix???.html; do
	if [ ! -f "${f%.html}.txt" ]; then
	    newResults=$(( $newResults + 1 ))
	    encoding=$(file -bi "$f")
	   if [ "$encoding" ==  "text/html; charset=utf-8" ]; then
	       strip-html.pl -p $minNbWordsParag "$f" "${f%.html}.txt"
	       size=$(cat "${f%.html}.txt" | wc -w)
	       if [ $nbDocs -gt 0 ] && [ $size -ge $minNbWordsDoc ]; then
		   nbDocs=$(( $nbDocs - 1 ))
	       else
		   rm -f "$f" "${f%.html}.txt" # we  don't need more documents or insufficient size
	       fi
	   else
	       rm -f "$f"
	   fi
	fi
    done
    if [ $newResults -lt 10 ]; then
	echo "$progName warning: end of Google results; $nbDocs documents missing." 1>&2
	nbDocs=0
    else
	index=$(( $index + 10 ))
    fi
done
echo
