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
CRAM=$SM/alignment/$SM.cram

printf -- "---\n[$(date)] Start bam2cram: $BAM\n"
if [[ -f $CRAM.crai ]]; then
    echo "Skip this step."
else
    $SAMTOOLS view -@7 -h $BAM \
        |sed "s/\tB[ID]\:Z\:[^\t]*//g;s/\tOQ\:Z\:[^\t]*//" \
        |$SAMTOOLS view -@7 -C -T $REF -o $CRAM
#        |parallel -j5 --pipe 'sed "s/\tB[ID]\:Z\:[^\t]*//g;s/\tOQ\:Z\:[^\t]*//"' \
#        |$SAMTOOLS view -@5 -C -T $REF -o $CRAM
    $SAMTOOLS index $CRAM
fi
printf -- "[$(date)] Finish bam2cram: $BAM\n---\n"
