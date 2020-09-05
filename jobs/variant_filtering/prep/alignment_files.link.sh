#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) <sample list file> <align fmt>"
    exit
fi

FSMLIST=$1
ALIGNFMT=$2

for SM in `cut -f1 $FSMLIST |sort -u`; do
    mkdir -p $SM/alignment
    awk -v sm="$SM" -v OFS='\t' '$1 == sm {print $2, $3}' $FSMLIST \
    |while read BAM LOC; do
         ln -sf $(readlink -f $LOC) $SM/alignment/$BAM
         if [[ $ALIGNFMT == "cram" ]]; then
             ls -lh $LOC.crai &> /dev/null \
                && ln -sf $(readlink -f $LOC.crai) $SM/alignment/$BAM.crai \
                || ln -sf $(readlink -f ${LOC/.cram/.crai}) $SM/alignment/${BAM/.cram/.crai}
         else
             ls -lh $LOC.bai &> /dev/null \
                && ln -sf $(readlink -f $LOC.bai) $SM/alignment/$BAM.bai \
                || ln -sf $(readlink -f ${LOC/.bam/.bai}) $SM/alignment/${BAM/.bam/.bai}
         fi
     done
done

