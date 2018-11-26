#!/bin/bash
#$ -cwd
#$ -pe threaded 18

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

source $(pwd)/run_info

set -eu -o pipefail

SM=$1

printf -- "---\n[$(date)] Start merge_bam.\n"

if [[ $(ls $SM/bam/$SM.*.sorted.bam|wc -l) == 1 ]]; then
    mv $SM/bam/$SM.*.sorted.bam $SM/bam/$SM.merged.bam
    rm $SM/bam/$SM.*.sorted.bam.bai
else
    $SAMBAMBA merge -t 18 $SM/bam/$SM.merged.bam $SM/bam/$SM.*.sorted.bam
    rm $SM/bam/$SM.*.sorted.bam{,.bai}
fi

printf -- "[$(date)] Finish merge_bam.\n---\n"
