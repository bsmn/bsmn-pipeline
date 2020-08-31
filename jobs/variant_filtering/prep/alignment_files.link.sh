#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) <sample list file> <align fmt>"
    false
fi

FSMLIST=$1
ALIGNFMT=$2

for SM in `cut -f1 $FSMLIST |sort -u`; do
    mkdir -p $SM/alignment
    awk -v sm="$SM" -v OFS='\t' '$1 == sm {print $2, $3}' $FSMLIST \
    |while read BAM LOC; do
         ln -sf $(readlink -f $LOC) $SM/alignment/$BAM
         if [[ $ALIGNFMT == "cram" ]]; then
             ln -sf $(readlink -f $LOC.crai) $SM/alignment/$BAM.crai
         else
             ln -sf $(readlink -f $LOC.bai) $SM/alignment/$BAM.bai
         fi
     done
done

