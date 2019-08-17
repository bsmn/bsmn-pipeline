#!/bin/bash
#$ -cwd
#$ -pe threaded 1

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [host] [sample]"
    false
fi

HOST=$1
SM=$2

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

printf -- "---\n[$(date)] Start submit_aln_jobs.\n"

CWD=$(pwd)
ssh -o StrictHostKeyChecking=No $HOST \
    "cd $CWD; $PYTHON3 $PIPE_HOME/genome_mapping/run_aln_jobs.py $SM"

printf -- "[$(date)] Finish submit_aln_jobs.\n---\n"
