#!/bin/bash
#$ -cwd
#$ -pe threaded 4

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

DONE=$SM/run_status/post_1.unmapped_reads.done

CRAM=$SM/alignment/$SM.cram
UNMAPPED=$SM/alignment/$SM.unmapped.bam

printf -- "---\n[$(date)] Start extracting unmapped reads: $CRAM\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    # An unmapped read whose mate is mapped
    $SAMTOOLS view -@ $NSLOTS -T $REF -f 4 -F 264 -u -o $SM/alignment/tmps1.bam $CRAM
    # A mapped read who’s mate is unmapped
    $SAMTOOLS view -@ $NSLOTS -T $REF -f 8 -F 260 -u -o $SM/alignment/tmps2.bam $CRAM
    # Both reads of the pair are unmapped
    $SAMTOOLS view -@ $NSLOTS -T $REF -f 12 -F 256 -u -o $SM/alignment/tmps3.bam $CRAM
    
    $SAMTOOLS merge -u - $SM/alignment/tmps[123].bam \
        |$SAMTOOLS sort -@ $((NSLOTS-1)) -m 3700M -n -o $UNMAPPED -

    rm $SM/alignment/tmps[123].bam
    touch $DONE
fi

printf -- "[$(date)] Finish extracting unmapped reads: $CRAM\n---\n"
