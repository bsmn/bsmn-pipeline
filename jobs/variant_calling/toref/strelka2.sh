#!/bin/bash

usage="usage: $(basename $0) -r <reference bam> -t <tool_info.txt> [-q <SGE queue> -d <out dir>] <BAM list file>"

while getopts r:t:q:d: opt; do
    case $opt in
        r) REFBAM=$OPTARG;;
        t) TOOLINFO=$OPTARG;;
        q) Q=$OPTARG;;
        d) STRELKAOUT=$OPTARG;;
    ?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $REFBAM ] || [ -z $TOOLINFO ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi
if [ -z $Q ]; then Q="4-day"; fi
if [ -z $STRELKAOUT ]; then STRELKAOUT="strelka"; fi

REFBAM=`readlink -f $REFBAM`
TOOLINFO=`readlink -f $TOOLINFO`
BAMLIST=$1
# MEMINFO=/research/bsi/archive/PI/Abyzov_Alexej_m124423/tertiary/s210166.Genomic_mosaicism_conditions/integrated/processed_data/condition_clones/191231-WG-E/docs/config/memory_info.txt
MEMINFO=/research/bsi/tools/pipelines/genome_gps/5.0.2/scripts/config/memory_info.txt

R=`basename $REFBAM`; R=${R/.bam/}
for i in `cat $BAMLIST`; do
    i=`readlink -f $i`
    S=`basename $i`; S=${S/.bam/}
    # OUTDIR=$PWD/strelka/${R}_${S}/
    OUTDIR=$(readlink -f $STRELKAOUT)/${R}_${S}
    if [ -d $OUTDIR ]; then continue; fi
    mkdir -p $OUTDIR/logs
    echo "$R vs. $S"
    /usr/local/sOGE/sge-8.1.9/bin/lx-amd64/qsub \
      -wd $OUTDIR/logs -q $Q -m a -b y \
      -l h_vmem=20G -l h_stack=10M -N R.strelka.$R.$S \
      /research/bsi/tools/pipelines/genome_gps/5.0.2/scripts/strelka.sh \
        -b $REFBAM -T $TOOLINFO -o $OUTDIR -v ${R}_${S}.strelka.vcf -t $i -M $MEMINFO
done

