#!/bin/bash
#$ -cwd
#$ -pe threaded 16 

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

BAM=$SM/bam/$SM.bam

printf -- "---\n[$(date)] Start Mutect single sample mode.\n"

# Add command

printf -- "[$(date)] Finish Mutect single sample mode.\n---\n"
