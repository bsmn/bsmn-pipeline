#!/bin/bash
#$ -cwd
#$ -pe threaded 12 

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [PU info]"
    false
fi

SM=$1
PU=$2

source $(pwd)/$SM/run_info

set -o nounset 
set -o pipefail
#set -x

DONE=$SM/run_status/aln_1.align_sort.$PU.done

printf -- "---\n[$(date)] Start align_sort.\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    mkdir -p $SM/alignment/
    $BWA mem -M -t $((NSLOTS - 4)) \
        -R "@RG\tID:$SM.$PU\tSM:$SM\tPL:illumina\tLB:$SM\tPU:$PU" \
        $REF $SM/fastq/$SM.$PU.R{1,2}.fastq.gz \
        |$SAMBAMBA view -S -f bam -l 0 /dev/stdin \
        |$SAMBAMBA sort -m 24GB -t 3 -o $SM/alignment/$SM.$PU.sorted.bam --tmpdir=tmp /dev/stdin 
    rm $SM/fastq/$SM.$PU.R{1,2}.fastq.gz
    touch $DONE
fi

printf -- "[$(date)] Finish align_sort.\n---\n"
