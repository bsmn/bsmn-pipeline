#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --signal=USR1@60

trap "exit 100" ERR

set -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

eval "$(conda shell.bash hook)"
conda activate --no-stack $CONDA_ENV

printf -- "---\n[$(date)] Start submit aln jobs.\n"

#for jid in $(awk -v job_id=$JOB_ID '$1 > job_id' $SM/run_jid);do
#    qdel $jid
#done

#ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
#    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_aln_jobs.py --sample-name $SM'"

if [ $TARGET_SEQ = "True" ]; then
    $PYTHON3 $PIPE_HOME/jobs/submit_aln_jobs.py --queue $Q --sample-name $SM -t
else
    $PYTHON3 $PIPE_HOME/jobs/submit_aln_jobs.py --queue $Q --sample-name $SM
fi

conda deactivate

printf -- "[$(date)] Finish submit aln jobs.\n---\n"
