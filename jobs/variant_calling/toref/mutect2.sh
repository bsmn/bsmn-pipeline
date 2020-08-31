#!/bin/bash

usage="usage: $(basename $0) -r <reference bam> -t <tool_info.txt> [-c chr:? -q <SGE queue> -d <out dir>] <BAM list file>"

while getopts r:ct:q:d: opt; do
    case $opt in
        r) REFBAM=$OPTARG;;
        t) TOOLINFO=$OPTARG;;
        c) CHRS="$(seq -s ' ' -f 'chr%g' 22) chrX chrY";;
        q) Q=$OPTARG;;
        d) MUTECTOUT=$OPTARG;;
    ?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $REFBAM ] || [ -z $TOOLINFO ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi

if [ -z $Q ]; then Q="7-day"; fi
if [ -z $CHRS ]; then CHRS="$(seq -s ' ' 22) X Y"; fi
if [ -z $MUTECTOUT ]; then MUTECTOUT="mutect"; fi

REFBAM=`readlink -f $REFBAM`
TOOLINFO=`readlink -f $TOOLINFO`
BAMLIST=$1
# MEMINFO=/research/bsi/archive/PI/Abyzov_Alexej_m124423/tertiary/s210166.Genomic_mosaicism_conditions/integrated/processed_data/condition_clones/191231-WG-E/docs/config/memory_info.txt
MEMINFO=/research/bsi/tools/pipelines/genome_gps/5.0.2/scripts/config/memory_info.txt

R=`basename $REFBAM`; R=${R/.bam/}
for i in `cat $BAMLIST`; do
    i=`readlink -f $i`
    S=`basename $i`; S=${S/.bam/}
    OUTDIR=$(readlink -f $MUTECTOUT)/${R}_${S}
    if [ -d $OUTDIR ]; then continue; fi
    mkdir -p $OUTDIR/logs
    echo "$R vs. $S"
    JIDS=()
    for chr in $CHRS; do
        JID=$(/usr/local/sOGE/sge-8.1.9/bin/lx-amd64/qsub \
                -wd $OUTDIR/logs -q $Q -r y -m a -V -b y \
                -l h_vmem=20G -l h_stack=10M -N R.mutect2.$R.$S.$chr \
                /research/bsi/tools/pipelines/genome_gps/5.0.2/scripts/mutect2.sh \
                  -b $REFBAM -T $TOOLINFO -o $OUTDIR -v ${R}_${S}.$chr.mutect.vcf -t $i -M $MEMINFO -l $chr \
              |tee /dev/tty |cut -f3 -d' '|cut -f1 -d'.')
        JIDS+=($JID)
    done
    qsub -hold_jid $(IFS=,; echo "${JIDS[*]}") -q $Q -o $OUTDIR/logs $(dirname $0)/mutect2.merge_chrs.sh $OUTDIR "$CHRS"
done
