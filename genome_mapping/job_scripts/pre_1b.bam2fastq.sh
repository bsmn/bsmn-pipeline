#!/bin/bash
#$ -cwd
#$ -pe threaded 18

set -eu -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [file name]"
    exit 1
fi

source $(pwd)/run_info

SM=$1
FNAME=$2

printf -- "---\n[$(date)] Start bam2fastq: $FNAME\n---\n"

$SAMTOOLS collate -uOn 128 $SM/downloads/$FNAME $SM/tmp.collate \
    |$SAMTOOLS fastq -O -F 0x900 -1 $SM/fastq/$SM.R1.fastq.gz -2 $SM/fastq/$SM.R2.fastq.gz -
rm $SM/downloads/$FNAME

printf -- "---\n[$(date)] Finish bam2fastq: $FNAME\n"
