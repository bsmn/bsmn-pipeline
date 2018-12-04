#!/bin/bash
#$ -cwd
#$ -pe threaded 1

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [host] [sample]"
    exit 1
fi

HOST=$1
SM=$2

source $(pwd)/$SM/run_info

set -eu -o pipefail

printf -- "---\n[$(date)] Start submit_aln_jobs.\n"

CWD=$(pwd)
ssh -o StrictHostKeyChecking=No $HOST \
    "cd $CWD; $PYTHON3 $PIPE_HOME/genome_mapping/submit_aln_jobs.py $SM"

printf -- "[$(date)] Finish submit_aln_jobs.\n---\n"
