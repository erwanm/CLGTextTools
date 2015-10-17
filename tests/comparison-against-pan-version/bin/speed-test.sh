#!/bin/bash


function generate {
    local targetDir="$1"
    local inputDoc="$2"
    local version="$3"

    [ -d "$targetDir/$version" ] || mkdir "$targetDir/$version" 
    tmpErr=$(mktemp)
    { time eval "generate-count-files-$version.sh \"$inputDoc\" \"$targetDir/$version\" >/dev/null 2>$tmpErr" ; } 2>"$targetDir/time-$version.out"
    cat $tmpErr 1>&2
    rm -f $tmpErr
    echo "Time for $version:"
    cat "$targetDir/time-$version.out" | grep "."
}




function multiLoad {
    local command="$1"
    local nbParallel="$2"

    for process in $(seq 1 $nbParallel); do
	eval "$command" >/dev/null &
    done
    wait
}


function load {
    local targetDir="$1"
    local version="$2"
    local command="$3"
    local nbParallel="$4"

    [ -d "$targetDir/$version" ] || mkdir "$targetDir/$version" 
    tmpErr=$(mktemp)
    { time multiLoad "$command" "$nbParallel" ; }  2>"$targetDir/time-$version.out"
    cat $tmpErr 1>&2
    rm -f $tmpErr
    echo "Time for $version:"
    cat "$targetDir/time-$version.out" | grep "."
}



if [ $# -ne 3 ]; then
    echo "usage: <input dir> <output dir> <nb parallel>" 1>&2
    echo 1>&2
    echo "  Runs a speed test which compares the PAN15 version with the 'new' version," 1>&2
    echo "  i.e. the CLGTextTools version. The test consists in running:" 1>&2
    echo "    - the generation of count files for a set of predefined obs types" 1>&2
    echo "    - the loading of obs counts (both from count file or from reading" 1>&2
    echo "      the doc file directly, for the 'new' version)" 1>&2
    echo "  the second test (loading) is run for <nb parallel> subprocesses simultaneously." 1>&2
    echo "  Input documents are read from <input dir>/*/*txt" 1>&2
    echo 1>&2
    exit 1
fi
inputDir="$1"
outputDir="$2"
nbParallel="$3"

[ -d "$outputDir" ] || mkdir "$outputDir"

for inputDoc in $inputDir/*/*txt; do
    sizeC=$(cat "$inputDoc" | wc -c)
    sizeW=$(cat "$inputDoc" | wc -w)
    echo "*** Processing $inputDoc: $sizeC chars, $sizeW words."
    countDir="$outputDir/count-files"
    [ -d "$countDir" ] || mkdir "$countDir" 
    echo "* Generating count files..."
    generate "$countDir" "$inputDoc" pan15
    generate "$countDir" "$inputDoc" new
    
    readDir="$outputDir/loading-process"
    [ -d "$readDir" ] || mkdir "$readDir" 
    echo " * Loading n-grams counts..."
    load "$readDir" "pan15" "read-pan15.sh '$inputDoc' '$countDir/pan15' '$readDir/pan15'" "$nbParallel"
    load "$readDir" "new-count-files" "read-new.sh '$inputDoc' 1 '$countDir/new' '$readDir/new-count-files'" "$nbParallel"
    load "$readDir" "new-input-doc" "read-new.sh '$inputDoc' 0 '$countDir/new' '$readDir/new-input-doc'" "$nbParallel"
    echo
    echo
done
