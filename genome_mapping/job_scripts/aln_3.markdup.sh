#!/bin/bash
#$ -cwd
#$ -pe threaded 18 

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

SM=$1

source $(pwd)/$SM/run_info

set -eu -o pipefail

printf -- "---\n[$(date)] Start markdup.\n"

$JAVA -Xmx26G -jar $PICARD MarkDuplicates \
    I=$SM/bam/$SM.merged.bam \
    O=$SM/bam/$SM.markduped.bam \
    METRICS_FILE=$SM/markduplicates_metrics.txt \
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
    CREATE_INDEX=true \
    TMP_DIR=tmp 

rm $SM/bam/$SM.merged.bam{,.bai}

printf -- "[$(date)] Finish markdup.\n---\n"
