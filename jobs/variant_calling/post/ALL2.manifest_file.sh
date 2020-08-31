#!/bin/bash

usage="usage: $(basename $0) -b <BAM list file> -d <VCF files dir> <out file>"

while getopts b:d: opt; do
    case $opt in
        b) FBAMLIST=$OPTARG;;
        d) VCFDIR=$OPTARG;;
	?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $FBAMLIST ] || [ -z $VCFDIR ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi

OUTFILE=$1
BAMLIST=$(cat $FBAMLIST)

for B1 in $BAMLIST; do
    N1=$(basename $B1); N1=${N1/.bam/}
    for B2 in $BAMLIST; do
        if [ $B1 = $B2 ]; then continue; fi
        N2=$(basename $B2); N2=${N2/.bam/}
        echo -e "$N1\t$N2\t$(readlink -f $VCFDIR/${N1}_${N2}.vcf)"
    done
done |sed "1i#Control\tCase\tFilename" >$OUTFILE

