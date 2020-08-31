#!/bin/bash
#$ -cwd
#$ -pe threaded 32
#$ -o logs
#$ -j y
#$ -l h_vmem=1G
#$ -V

trap "exit 100" ERR
set -e -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <variants list file>"
    exit 1
fi

INFILE=$1
OUTFILE=${INFILE%.*}.mask.gnomAD.txt

STRICT_MASK=/home/mayo/m216456/Playground/bsmn-pipeline/resources/hg19/20141020.strict_mask.whole_genome.fasta.gz
# GNOMAD=/home/mayo/m216456/Playground/bsmn-pipeline/resources/gnomAD.AFover.0.001.b37.txt.gz
GNOMAD=/home/mayo/m216456/Playground/bsmn-pipeline/resources/gnomAD.r2.1.1.AFover0.001.both.txt.gz

if [ -z $NSLOTS ]; then NSLOTS=$(nproc); fi
NPROC=$((NSLOTS-2))
NLINE=$(($(grep -v ^# $INFILE | wc -l)/$(($NPROC-1))))
if [[ $NLINE -lt 1 ]]; then NLINE=1; fi

printf -- "[$(date)] Annotate variants with gnomAD and 1000G strict mask info.\n---\n"
SECONDS=0

echo "[INFO] INPUT: $INFILE"
echo "[INFO] OUTPUT: $OUTFILE"
echo "[INFO] $NPROC processors; $NLINE lines per one processor"

annotate() {
    local STRICT_MASK=$1
    local GNOMAD=$2
    cut -f1-4 \
    |while read -r CHR POS REF ALT; do
         P=`samtools faidx $STRICT_MASK ${CHR/chr/}:$POS-$POS |tail -1`
         G=`zcat $GNOMAD |grep ${CHR/chr/}.$POS.$REF.$ALT || printf "N"`
         if [ "$G" != "N" ]; then G="Y"; fi
         echo -e "$CHR\t$POS\t$REF\t$ALT\t$G\t$P"
     done
}
export -f annotate

grep -v ^# $INFILE \
|parallel --pipe -N $NLINE -j $NPROC annotate $STRICT_MASK $GNOMAD \
|awk -v H="$(head -1 $INFILE)\tgnomAD>0.001\tMask" -v OFS='\t' \
     'BEGIN { print H }
      NR==FNR {
          ann[$1, $2, $3, $4] = $5 "\t" $6
          next
      } {
          if ($1 !~ /^#/) print $0, ann[$1, $2, $3, $4]
      }' - $INFILE \
>$OUTFILE


printf -- "---\n[$(date)] Done.\n"

elapsed=$SECONDS
printf -- "\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

