#!/bin/bash

usage="usage: $(basename $0) [-s <0~1>] [-n <# of samples>] [-p] <score file>"

while getopts s:n:p opt; do
    case $opt in
        s) SFILTER=$OPTARG;;
        n) NFILTER=$OPTARG;;
        p) POLY=true;; # Score cutoff based on polynomial graph
	?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ $# -lt 1 ]; then echo $usage; exit 1; fi

SCOREFILE=$1

if [ -z $SFILTER ]; then SFILTER=0.75; fi
if [ -z $NFILTER ]; then NFILTER=1; fi

grep -v ^# $SCOREFILE \
|if [ -z $POLY ]; then
     awk -v S=$SFILTER -v N=$NFILTER \
         '{ n = gsub(",", ",", $7) + 1; if ($5 > S && n >= N) print }' OFS='\t' -
 else
     awk -v S=$SFILTER -v N=$NFILTER \
         '{ n = gsub(",", ",", $7) + 1; if ($5 > 0.25 && sqrt($5^2 + $6^2) > S && n >= N) print }' OFS='\t' -
 fi \
|cut -f1-4,7 |sort -k1,1V -k2,2g \
|cat <(head -1 $SCOREFILE |cut -f1-4,7) -

