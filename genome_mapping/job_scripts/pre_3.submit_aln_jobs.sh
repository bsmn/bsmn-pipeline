#!/bin/bash
#$ -cwd
#$ -pe threaded 1

set -eu -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [host] [sample]"
    exit 1
fi

source $(pwd)/run_info

HOST=$1
SM=$2

printf -- "[$(date)] Start submit_aln_jobs.\n---\n"

CWD=$(pwd)
ssh -o StrictHostKeyChecking=No $HOST "cd $CWD; $PYTHON3 $CMD_HOME/submit_aln_jobs.py $SM"

printf -- "---\n[$(date)] Finish submit_aln_jobs.\n"
