#!/bin/bash
#$ -cwd
#$ -pe threaded 16

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

BAM=$SM/alignment/$SM.bam
UNMAPPED=$SM/alignment/$SM.unmapped.bam

printf -- "---\n[$(date)] Start extracting unmapped reads: $BAM\n"
if [[ -f $BAM ]]; then
    # An unmapped read whose mate is mapped
    $SAMTOOLS view -@16 -u -f 4 -F 264 -o $SM/alignment/tmps1.bam $BAM
    # A mapped read who’s mate is unmapped
    $SAMTOOLS view -@16 -u -f 8 -F 260 -o $SM/alignment/tmps2.bam $BAM
    # Both reads of the pair are unmapped
    $SAMTOOLS view -@16 -u -f 12 -F 256 -o $SM/alignment/tmps3.bam $BAM
    
    $SAMTOOLS merge -u - $SM/alignment/tmps[123].bam \
        |$SAMTOOLS sort -@15 -m 3.8G -n -o $UNMAPPED -
    $SAMTOOLS index $UNMAPPED

    rm $SM/alignment/tmps[123].bam
else
    echo "Skip this step."
fi
printf -- "[$(date)] Finish extracting unmapped reads: $BAM\n---\n"
