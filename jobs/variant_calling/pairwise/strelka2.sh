#!/bin/bash

usage="usage: $(basename $0) -t <tool_info.txt> [-q <SGE queue> -d <out dir>] <BAM list file>"

while getopts t:q:d: opt; do
    case $opt in
        t) TOOLINFO=$OPTARG;;
        q) Q=$OPTARG;;
        d) STRELKAOUT=$OPTARG;;
    ?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $TOOLINFO ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi
if [ -z $Q ]; then Q="4-day"; fi
if [ -z $STRELKAOUT ]; then STRELKAOUT="strelka"; fi

TOOLINFO=`readlink -f $TOOLINFO`
BAMLIST=$1
# MEMINFO=/research/bsi/archive/PI/Abyzov_Alexej_m124423/tertiary/s210166.Genomic_mosaicism_conditions/integrated/processed_data/condition_clones/191231-WG-E/docs/config/memory_info.txt
MEMINFO=/research/bsi/tools/pipelines/genome_gps/5.0.2/scripts/config/memory_info.txt

for i in `cat $BAMLIST`; do
    i=`readlink -f $i`
    for j in `cat $BAMLIST`; do
        j=`readlink -f $j`
        if [ $i == $j ]; then continue; fi
        norm=`basename $i|cut -d "." -f1`
        tum=`basename $j|cut -d "." -f1`
        # OUTDIR=$PWD/strelka/${norm}_${tum}/
        OUTDIR=$(readlink -f $STRELKAOUT)/${norm}_${tum}
        if [ -d $OUTDIR ]; then continue; fi
        mkdir -p $OUTDIR/logs
        echo "$norm vs. $tum"
        /usr/local/sOGE/sge-8.1.9/bin/lx-amd64/qsub \
          -wd $OUTDIR/logs -q $Q -m a -b y \
          -l h_vmem=20G -l h_stack=10M -N strelka.$norm.$tum \
          /research/bsi/tools/pipelines/genome_gps/5.0.2/scripts/strelka.sh \
            -b $i -T $TOOLINFO -o $OUTDIR -v ${norm}_${tum}.strelka.vcf -t $j -M $MEMINFO
    done
done

