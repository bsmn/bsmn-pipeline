#!/bin/bash

usage="usage: $(basename $0) [-s <0~1>] [-m <0~1>] [-n <# of samples>] [-P] [-v] <score file>"

while getopts s:m:n:Pv opt; do
    case $opt in
        s) SCUTOFF=$OPTARG;;
        m) MCUTOFF=$OPTARG;;
        n) NCUTOFF=$OPTARG;;
        P) POLYOFF=true;; # Turn off the score cutoff based on polynomial graph
        v) OUTCOLS=1-4,7-9;;
	?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ $# -lt 1 ]; then echo $usage; exit 1; fi

SCOREFILE=$1

if [ -z $SCUTOFF ]; then SCUTOFF=0.75; fi
if [ -z $MCUTOFF ]; then MCUTOFF=0.25; fi
if [ -z $NCUTOFF ]; then NCUTOFF=1; fi
if [ -z $OUTCOLS ]; then OUTCOLS=1-4,7-8; fi

grep -v ^# $SCOREFILE \
|if [ -z $POLYOFF ]; then
     awk -v S=$SCUTOFF -v M=$MCUTOFF -v N=$NCUTOFF '$5 > M && sqrt($5^2 + $6^2) > S && $7 >= N' OFS='\t' -
 else
     awk -v S=$SCUTOFF -v N=$NCUTOFF '$5 > S && $7 >= N' OFS='\t' -
 fi \
|cut -f$OUTCOLS |sort -k1,1V -k2,2g \
|cat <(head -1 $SCOREFILE |cut -f$OUTCOLS) -

