#!/bin/bash
#$ -cwd
#$ -pe threaded 24

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

printf -- "---\n[$(date)] Start merge_bam.\n"

rmdir $SM/downloads $SM/fastq

if [[ $(ls $SM/alignment/$SM.*.sorted.bam|wc -l) == 1 ]]; then
    mv $SM/alignment/$SM.*.sorted.bam $SM/alignment/$SM.merged.bam
    rm $SM/alignment/$SM.*.sorted.bam.bai
else
    $SAMBAMBA merge -t $NSLOTS $SM/alignment/$SM.merged.bam $SM/alignment/$SM.*.sorted.bam
    rm $SM/alignment/$SM.*.sorted.bam{,.bai}
fi

printf -- "[$(date)] Finish merge_bam.\n---\n"
