#!/bin/bash
#$ -cwd
#$ -j y
#$ -o logs
#$ -pe threaded 12
#$ -l h_vmem=2G
#$ -V

trap "exit 100" ERR
set -eu -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $JOB_NAME <sample name> <ploidy>"
    exit 1
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info


if [[ $SKIP_CNVNATOR == "True" ]]; then
    IN=$SM/candidates/$SM.ploidy_$PL.txt
else
    IN=$SM/candidates/$SM.ploidy_$PL.cnv.txt
fi
VAF=$SM/vaf/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.PASS.P.vaf
if [[ $ALIGNFMT == "cram" ]]; then
    BAM=$SM/alignment/$SM.cram
else
    BAM=$SM/alignment/$SM.bam
fi

STR=$SM/strand/${IN##*/}.str
REP=$SM/repeat/${IN##*/}.rep

mkdir -p $SM/strand $SM/repeat
if [[ $REFVER == "hg19" ]]; then
    export XDG_CACHE_HOME=$PIPE_HOME/resources/hg19.cache
else
    export XDG_CACHE_HOME=$PIPE_HOME/resources/b37.cache
fi

SECONDS=0

printf -- "[$(date)] Start generating strand bias info.\n"
printf -- "Sample: $SM \n"
printf -- "Ploidy: $PL \n---\n"
DONE1=$SM/run_status/Mayo_filters.strand.ploidy_$PL.done
if [[ -f $DONE1 ]]; then
    echo "Skip calculating strand bias. Already done."
else
    cut -f1-4 $IN | $PYTHON3 $PIPE_HOME/utils/strand_bias.2.py -q 20 -Q 20 -b $BAM -n $((NSLOTS-2)) > $STR
    mkdir -p $SM/run_status
    touch $DONE1
fi
printf -- "---\n[$(date)] Finish generating strand bias info.\n"

printf -- "\n[$(date)] Start generating repeat info.\n---\n"
DONE2=$SM/run_status/Mayo_filters.repeat.ploidy_$PL.done
if [[ -f $DONE2 ]]; then
    echo "Skip calculating repeat info. Already done."
else
    cut -f1-4 $IN | $PYTHON3 $PIPE_HOME/utils/repeat.2.py -r $REF -n $((NSLOTS-2)) > $REP
    mkdir -p $SM/run_status
    touch $DONE2
fi
printf -- "---\n[$(date)] Finish generating repeat info.\n"


printf -- "\n[$(date)] Start applying mayo filters.\n---\n"
printf -- "[IN] Variants before extra filtering: $(cat $IN | wc -l) \n"

if [[ $SKIP_CNVNATOR == "True" ]]; then
    CAND=$SM/candidates/$SM.ploidy_$PL.mayo.txt
else
    CAND=$SM/candidates/$SM.ploidy_$PL.cnv.mayo.txt
fi

paste <(awk 'NR==FNR{a[$1,$2,$3,$4]=$0;next}{$5=a[$1,$2,$3,$4];print $5}' OFS='\t' <(tail -n+2 $VAF) <(cut -f1-4 $IN)) \
      <(cut -f9,15,16,18 $STR | tail -n+2) \
      <(cut -f5- $REP | tail -n+2) \
          |awk '$14 < 4 && $15 < 10 #repeat filter' \
          |awk '$6 == $7 + $8 #multiallelic filter' \
          |awk '$11 >= 1 && $12 >=1 #both strands in alt reads' \
          |awk '$10 >= 0.05 || $13 >= 0.05 #p_poisson or p_fisher' \
          |cut -f1-4 > $CAND

if [[ ! -s $CAND ]]; then
    rm -f $CAND
    printf -- "[OUT] Variants after extra filtering: 0 \n"
else
    printf -- "[OUT] Variants after extra filtering: $(cat $CAND | wc -l) \n"
fi

printf -- "---\n[$(date)] Finish applying mayo filters.\n"

elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

