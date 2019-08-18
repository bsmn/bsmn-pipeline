#!/bin/bash
#$ -cwd
#$ -pe threaded 1

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

printf -- "---\n[$(date)] Start submit aln jobs.\n"

CWD=$(pwd)
ssh -o StrictHostKeyChecking=No $SGE_O_HOST \
    "cd $CWD; $PYTHON3 $PIPE_HOME/genome_mapping/run_aln_jobs.py $SM"

printf -- "[$(date)] Finish submit aln jobs.\n---\n"
