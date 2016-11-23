#!/bin/bash

# EM April 15

source common-lib.sh
source file-lib.sh

timeout=60s
progName=$(basename "$BASH_SOURCE")
debug=0
startIndex=1
additionalArgs=""
cseEnglish="012262014784491565402:zirv0a__hpe"
cseDutch="012262014784491565402:-c2lxyir3y8"
cseSpanish="012262014784491565402:b2j-tey7w6e"
cseGreek="012262014784491565402:qcz522zr1us"
cseGerman="012262014784491565402:6tttsogrttm"
cseFrench="012262014784491565402:hjgh1miux_4"
cseId="$cseEnglish" # default


function usage {
  echo
  echo "Usage: $progName [options] <query> <output prefix> <Google API key>"
  echo
  echo "  sends a query to a specific Google Custom Search Engine and returns the content"
  echo "  of the pages behind the result links. Use '+' as separator if multiple words in"
  echo "  the query. Resulting documents are written as individual <output prefix><NNN>.html"
  echo "  files, where <NNN> is the number of the link in google search results."
  echo
  echo "  <Google API key> is generated in the developer console at: "
  echo "  https://console.developers.google.com/project (API & Auth / Credentials)"
  echo "  Remark: max 100 queries a day with free account, and  th results might contain "
  echo "  commercial links, depending on the CSE definition."
  echo
  echo "  If Google doesn't find any result (or not the maximum number by page, 10),"
  echo "  the corresponding output files are (quite logically) not created. The calling"
  echo "   program can check whether these files exist to test this case."
  echo
  echo "  Options:"
  echo "    -h this help"
  echo "    -n <start> extracts search results starting at this index (default $startIndex),"
  echo "       Example: '-n 21' gives the third page of results."
  echo "    -l <language> Specify the CSE language and restrict results to this language"
  echo "       default: 'english'."
  echo "    -c <CSE id> use a specific google search engine, defined at:"
  echo "       https://cse.google.com/cse."
  echo "    -d debug: keep json result file and print its name"
  echo "    -t <timeout> default: '$timeout'"
  echo ""
  echo
}



OPTIND=1
while getopts 'hn:l:c:dt:' option ; do 
    case $option in
	"h" ) usage
 	      exit 0;;
	"n" ) startIndex="$OPTARG";;
	"d" ) debug=1;;
	"t" ) timeout="$OPTARG";;
	"l" ) if [ "$OPTARG" == "english" ]; then
	        additionalArgs="$additionalArgs&lr=lang_en"
		cseId="$cseEnglish"
	      elif [ "$OPTARG" == "dutch" ]; then
	        additionalArgs="$additionalArgs&lr=lang_nl"
		cseId="$cseDutch"
	      elif [ "$OPTARG" == "spanish" ]; then
	        additionalArgs="$additionalArgs&lr=lang_es"
		cseId="$cseSpanish"
	      elif [ "$OPTARG" == "greek" ]; then
	        additionalArgs="$additionalArgs&lr=lang_el"
		cseId="$cseGreek"
	      elif [ "$OPTARG" == "french" ]; then
	        additionalArgs="$additionalArgs&lr=lang_fr"
		cseId="$cseFrench"
	      elif [ "$OPTARG" == "german" ]; then
	        additionalArgs="$additionalArgs&lr=lang_de"
		cseId="$cseGerman"
	      else
	        echo "Error: unknown language id '$OPTARG'." 1>&2
		exit 3
	      fi;;
	"c" ) cseId="$OPTARG";;
	"?" ) 
	    echo "Error, unknow option." 1>&2
            printHelp=1;;
    esac
done
shift $(($OPTIND - 1))
if [ $# -ne 3 ]; then
    echo "Error: expecting 3 args." 1>&2
    printHelp=1
fi
if [ ! -z "$printHelp" ]; then
    usage 1>&2
    exit 1
fi
query="$1"
outputPrefix="$2"
apiKey="$3"

jsonResFile=$(mktemp --tmpdir "tmp.$progName.XXXXXXXXX")
if [ $debug -ne 0 ]; then
    echo "$progName: json temporary file=$jsonResFile" 1>&2
fi
wget -q -O "$jsonResFile" "https://www.googleapis.com/customsearch/v1?q=${query}&cx=${cseId}&start=${startIndex}${additionalArgs}&fields=items(link)&key=${apiKey}"
errCode="$?"
if [ $errCode -ne 0 ]; then
    echo "$progName error: Google query failed (error code $errCode)" 1>&2
    rm -f "$jsonResFile"
    exit 5
fi
num=$startIndex
cat "$jsonResFile" | grep "\"link\":" | sed 's/\s*.link.:\s*//g' | sed 's/^"//g' | sed 's/"$//g' | while read link; do 
    numStr=$(printf "%03d" $num)
    timeout $timeout wget -q -O "${outputPrefix}${numStr}.html" "$link"
    num=$(( $num + 1 ))
done
if [ $debug -eq 0 ]; then
    rm -f "$jsonResFile"
fi


