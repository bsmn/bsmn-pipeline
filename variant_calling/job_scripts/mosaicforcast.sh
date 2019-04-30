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

printf -- "---\n[$(date)] Start MosaicForcast.\n"

# Add command

printf -- "[$(date)] Finish MosaicForcast.\n---\n"
