#!/bin/bash

usage="usage: $(basename $0) -d <gatk-hc dir> -p <ploidy> [-p <ploidy> ...] <sample list file>"

while getopts d:p: opt; do
    case $opt in
        d) VCFDIR=$OPTARG;;
        p) P+=($OPTARG);;
    ?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $VCFDIR ] || [ -z $P ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi

FSMLIST=$1

for SM in `cut -f1 $FSMLIST |sort -u`; do
    mkdir -p $SM/gatk-hc
    for PL in ${P[@]}; do
        ln -sf $(readlink -f $VCFDIR/$SM.ploidy_$PL.vcf.gz) $SM/gatk-hc/$SM.ploidy_$PL.vcf.gz
        ln -sf $(readlink -f $VCFDIR/$SM.ploidy_$PL.vcf.gz.tbi) $SM/gatk-hc/$SM.ploidy_$PL.vcf.gz.tbi
    done
done

