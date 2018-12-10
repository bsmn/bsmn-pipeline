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

if [[ $(ls $SM/bam/$SM.*.sorted.bam|wc -l) == 1 ]]; then
    mv $SM/bam/$SM.*.sorted.bam $SM/bam/$SM.merged.bam
    rm $SM/bam/$SM.*.sorted.bam.bai
else
    $SAMBAMBA merge -t $NSLOTS $SM/bam/$SM.merged.bam $SM/bam/$SM.*.sorted.bam
    rm $SM/bam/$SM.*.sorted.bam{,.bai}
fi

printf -- "[$(date)] Finish merge_bam.\n---\n"
