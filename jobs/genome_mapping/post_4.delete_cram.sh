#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=1G
##SBATCH --time=04:00:00
#SBATCH --time=30:00:00
#SBATCH --signal=USR1@60

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

if [[ $ALIGNFMT == "cram" ]]; then
    INDEX_SUFFIX="crai"
else
    INDEX_SUFFIX="bai"
fi

printf -- "---\n[$(date)] Start delete: $SM.$ALIGNFMT{,.$INDEX_SUFFIX}\n"

rm $SM/alignment/$SM.$ALIGNFMT{,.$INDEX_SUFFIX}

printf -- "[$(date)] Finish delete: $SM.$ALIGNFMT{,.$INDEX_SUFFIX}\n---\n"
