#!/bin/bash
#$ -cwd
#$ -pe threaded 8

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

DONE1=$SM/run_status/pre_2.bam2cram.1-sam.done
DONE2=$SM/run_status/pre_2.bam2cram.2-cram.done
DONE3=$SM/run_status/pre_2.bam2cram.3-index.done

BAM=$SM/alignment/$SM.bam
SAM=$SM/alignment/$SM.sam
CRAM=$SM/alignment/$SM.cram

printf -- "---\n[$(date)] Start bam2cram: $BAM\n"

if [[ -f $DONE1 ]]; then
    echo "Skip the sam generation step."
else
    [[ -f $SAM ]] && rm $SAM
    $SAMBAMBA view -t $NSLOTS -h $BAM > $SAM
    rm $SM/alignment/$SM.ba*
    touch $DONE1
fi

if [[ -f $DONE2 ]]; then
    echo "Skip the cram generation step."
else
    mkdir -p $SM/tmp
    parallel --tmpdir $SM/tmp -a $SAM -j $((NSLOTS-2)) -k --pipepart \
        'sed "s/\tB[ID]\:Z\:[^\t]*//g;s/\tOQ\:Z\:[^\t]*//"' \
        |$SAMTOOLS view -@ $((NSLOTS-6)) -C -T $REF -o $CRAM
    rm -r $SAM $SM/tmp
    touch $DONE2
fi

if [[ -f $DONE3 ]]; then
    echo "Skip the cram indexing step."
else
    $SAMTOOLS index $CRAM
    touch $DONE3
fi

printf -- "[$(date)] Finish bam2cram: $BAM\n---\n"
