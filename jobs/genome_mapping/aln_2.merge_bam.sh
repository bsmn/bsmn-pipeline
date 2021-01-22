#!/bin/bash
#$ -cwd
#$ -pe threaded 16

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

DONE=$SM/run_status/aln_2.merge_bam.done

printf -- "---\n[$(date)] Start merge_bam.\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    [[ -d $SM/downloads ]] && rmdir $SM/downloads
    [[ -d $SM/fastq ]] && rmdir $SM/fastq

    if [[ $(ls $SM/alignment/$SM.*.sorted.bam|wc -l) == 1 ]]; then
        mv $SM/alignment/$SM.*.sorted.bam $SM/alignment/$SM.merged.bam
        mv $SM/alignment/$SM.*.sorted.bam.bai $SM/alignment/$SM.merged.bam.bai
    else
        $SAMBAMBA merge -t $NSLOTS $SM/alignment/$SM.merged.bam $SM/alignment/$SM.*.sorted.bam
        rm $SM/alignment/$SM.*.sorted.bam{,.bai}
    fi
    touch $DONE
fi

rm -rf $SM/tmp

printf -- "[$(date)] Finish merge_bam.\n---\n"
