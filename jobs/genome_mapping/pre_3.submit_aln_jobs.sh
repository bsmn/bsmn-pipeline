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

ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_aln_jobs.py --sample-name $SM'"

printf -- "[$(date)] Finish submit aln jobs.\n---\n"
