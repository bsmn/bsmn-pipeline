#!/bin/bash
#$ -cwd
#$ -pe threaded 1

if [[ $# -lt 3 ]]; then
    echo "Usage: $(basename $0) [sample name] [file name] [synapse id]"
    exit 1
fi

source $(pwd)/run_info

set -eu -o pipefail

SM=$1
FNAME=$2
SINID=$3

printf -- "---\n[$(date)] Start download: $FNAME\n"
mkdir -p $SM/bam 

# $SYNAPSE get $SINID --downloadLocation $SM/bam/
printf -- "[$(date)] Finish downlaod: $FNAME\n---\n"
