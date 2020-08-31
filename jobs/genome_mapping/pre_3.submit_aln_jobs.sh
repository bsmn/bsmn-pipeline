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

for jid in $(awk -v job_id=$JOB_ID '$1 > job_id' $SM/run_jid);do
    qdel $jid
done

#ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
#    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_aln_jobs.py --sample-name $SM'"

if [ $TARGET_SEQ = "True" ]; then
    $PYTHON3 $PIPE_HOME/jobs/submit_aln_jobs.py --sample-name $SM -t
else
    $PYTHON3 $PIPE_HOME/jobs/submit_aln_jobs.py --sample-name $SM
fi

printf -- "[$(date)] Finish submit aln jobs.\n---\n"
