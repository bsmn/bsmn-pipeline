#!/bin/bash
#$ -cwd
#$ -pe threaded 24 

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

printf -- "---\n[$(date)] Start align_sort.\n"

mkdir -p $SM/bam
$BWA mem -M -t $((NSLOTS - 4)) \
    -R "@RG\tID:$SM.$PU\tSM:$SM\tPL:illumina\tLB:$SM\tPU:$PU" \
    $REF $SM/fastq/$SM.$PU.R{1,2}.fastq.gz \
    |$SAMBAMBA view -S -f bam -l 0 /dev/stdin \
    |$SAMBAMBA sort -m 24GB -t 3 -o $SM/bam/$SM.$PU.sorted.bam --tmpdir=tmp /dev/stdin 
rm $SM/fastq/$SM.$PU.R{1,2}.fastq.gz

printf -- "[$(date)] Finish align_sort.\n---\n"
