#!/bin/bash
#$ -cwd
#$ -pe threaded 12

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

printf -- "---\n[$(date)] Start markdup.\n"

$JAVA -Xmx36G -jar $PICARD MarkDuplicates \
    I=$SM/bam/$SM.merged.bam \
    O=$SM/bam/$SM.markduped.bam \
    METRICS_FILE=$SM/markduplicates_metrics.txt \
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
    CREATE_INDEX=true \
    TMP_DIR=tmp 

rm $SM/bam/$SM.merged.bam{,.bai}

printf -- "[$(date)] Finish markdup.\n---\n"
