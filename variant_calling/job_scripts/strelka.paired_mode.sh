#!/bin/bash
#$ -cwd
#$ -pe threaded 16 

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [control sample name]"
    false
fi

SM=$1
CTR=$2

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

BAM1=$SM/bam/$SM.bam
BAM2=$SM/bam/$CTR.bam

printf -- "---\n[$(date)] Start Strelka paired sample mode.\n"

# Add command

printf -- "[$(date)] Finish Strelka paired sample mode.\n---\n"
