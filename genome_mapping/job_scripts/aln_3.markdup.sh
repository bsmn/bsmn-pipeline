#!/bin/bash
#$ -cwd
#$ -pe threaded 18 

set -eu -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

source $(pwd)/run_info

SM=$1

printf -- "[$(date)] Start markdup.\n---\n"

$JAVA -Xmx26G -jar $PICARD MarkDuplicates \
    I=$SM/bam/$SM.merged.bam \
    O=$SM/bam/$SM.markduped.bam \
    METRICS_FILE=$SM/markduplicates_metrics.txt \
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
    CREATE_INDEX=true \
    TMP_DIR=tmp 

rm $SM/bam/$SM.merged.bam{,.bai}

printf -- "---\n[$(date)] Finish markdup.\n"
