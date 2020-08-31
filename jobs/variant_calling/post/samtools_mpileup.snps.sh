#!/bin/bash
#$ -cwd
#$ -pe threaded 32
#$ -o logs
#$ -j y
#$ -l h_vmem=1G
#$ -V

trap "exit 100" ERR

set -e -o pipefail

usage="usage: $(basename $0) -i <snps.txt> -o <out dir> [-n <target name>] [-r <b37 (default), hg19 or hg38>] <BAM file> [<BAM file> ...]"

while getopts r:i:o:n: opt; do
    case $opt in
        r) RVER=$OPTARG;;
        i) IN=$OPTARG;;
        o) OUTDIR=$OPTARG;;
        n) TNAME=$OPTARG;;
        ?) echo $usage; exit 100
    esac
done

shift $(($OPTIND-1))

if [ -z $IN ] || [ -z $OUTDIR ] || [ $# -lt 1 ]; then
    echo $usage; exit 100
elif [ -z $RVER ]; then
    RVER="b37"
fi

BAMS=$*;

if [ -z $NSLOTS ]; then NSLOTS=$(nproc); fi

SECONDS=0

printf -- "[$(date)] Start calculating VAF info.\n"
printf -- "BAM file(s): $BAMS \n---\n"

mkdir -p $OUTDIR

FNAME=$(basename $IN)
if [ -z $TNAME ]; then
    FNAME=${FNAME%.*}.$(basename $1)
    FNAME=${FNAME/.bam/}; FNAME=${FNAME/.cram/}
else
    FNAME=${FNAME%.*}.$TNAME
fi
OUTFILE=$OUTDIR/$FNAME.somatic.vaf

TEMPIN=/tmp/$(uuidgen)
grep -v ^# $IN \
|if [ $RVER = "b37" ]; then sed 's/^chr//'; else sed '/^chr/! s/^/chr/'; fi \
>$TEMPIN

PIPE_HOME=/research/bsi/projects/staff_analysis/m216456/Playground/bsmn-pipeline

if [[ $RVER == "hg19" ]]; then
    export XDG_CACHE_HOME=$PIPE_HOME/resources/hg19.cache
elif [[ $RVER == "hg38" ]]; then
    export XDG_CACHE_HOME=$PIPE_HOME/resources/hg38.cache
elif [[ $RVER == "b37" ]]; then
    export XDG_CACHE_HOME=$PIPE_HOME/resources/b37.cache
else
    echo "Unknown reference version: $RVER"; exit 1
fi

python3 $PIPE_HOME/utils/somatic_vaf.2.py -q 20 -Q 20 -b "$BAMS" -n $((NSLOTS-2)) $TEMPIN \
|awk -v CHRIN=$(grep -v ^# $IN |head -1 |cut -f1) -v OFS='\t' \
     '{ if (!/^#/ && !/^chr/ && CHRIN ~ /^chr/) sub(/^/, "chr", $1)
        else if (!/^#/ && /^chr/ && CHRIN !~ /^chr/) sub(/^chr/, "", $1)
        print }' \
>$OUTFILE

rm $TEMPIN

printf -- "---\n[$(date)] Finish calculating VAF info.\n"


elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."
