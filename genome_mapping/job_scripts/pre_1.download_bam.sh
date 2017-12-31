#!/bin/bash
#$ -cwd
#$ -pe threaded 1

set -eu -o pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $(basename $0) [sample name] [file name] [synapse id]"
    exit 1
fi

source $(pwd)/run_info

SM=$1
FNAME=$2
SINID=$3

printf -- "[$(date)] Start download: $FNAME\n---\n"

mkdir -p $SM/downloads $SM/fastq
$SYNAPSE get $SINID --downloadLocation $SM/downloads/

printf -- "---\n[$(date)] Finish downlaod: $FNAME\n"
printf -- "---\n[$(date)] Start bam2fastq: $FNAME\n---\n"

$SAMTOOLS collate -uOn 128 $SM/downloads/$FNAME $SM/tmp.collate \
    |$SAMTOOLS fastq -F 0x900 -1 $SM/fastq/$SM.R1.fastq.gz -2 $SM/fastq/$SM.R2.fastq.gz -
rm $SM/downloads/$FNAME

printf -- "---\n[$(date)] Finish bam2fastq: $FNAME\n"
