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
