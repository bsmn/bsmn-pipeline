#!/bin/bash
#$ -cwd
#$ -pe threaded 72 

set -eu -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

source $(pwd)/run_info

SM=$1

printf -- "[$(date)] Start markdup.\n---\n"

$SAMBAMBA markdup -t 72 --tmpdir=tmp $SM/bam/$SM.merged.bam $SM/bam/$SM.markduped.bam 
rm $SM/bam/$SM.merged.bam{,.bai}

printf -- "---\n[$(date)] Finish markdup.\n"
