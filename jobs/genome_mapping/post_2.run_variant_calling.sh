#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=1G
##SBATCH --time=04:00:00
#SBATCH --time=30:00:00
#SBATCH --signal=USR1@60

trap "exit 100" ERR

set -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

# Already done in pre_3.submit_aln_jobs.sh
#eval "$(conda shell.bash hook)"
#conda activate --no-stack $CONDA_ENV

printf -- "---\n[$(date)] Start submit variant calling jobs.\n"

if [[ $RUN_GATK_HC = "False" ]] \
    && [[ $RUN_MUTECT_SINGLE = "False" ]] \
    && [[ $RUN_CNVNATOR = "False" ]]; then
    echo "Skip this step."
else
    if [[ $RUN_GATK_HC = "True" ]]; then
        #ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
        #    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_gatk-hc_jobs.py --ploidy $PLOIDY --sample-name $SM'"
        $PYTHON3 $PIPE_HOME/jobs/submit_gatk-hc_jobs.py --queue $Q --ploidy $PLOIDY --sample-name $SM
        echo "Submitted gatk-hc jobs."
    fi
    if [[ $RUN_MUTECT_SINGLE = "True" ]]; then
        #ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
        #    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_mutect-single_jobs.py --sample-name $SM'"
        $PYTHON3 $PIPE_HOME/jobs/submit_mutect-single_jobs.py --sample-name $SM
    fi
    if [[ $RUN_CNVNATOR = "True" ]]; then
        #ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
        #    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_cnvnator_jobs.py --sample-name $SM'"
        $PYTHON3 $PIPE_HOME/jobs/submit_cnvnator_jobs.py --sample-name $SM
        echo "Submitted cnvnator jobs."
    fi
fi

#conda deactivate

printf -- "[$(date)] Finish submit variant calling jobs.\n---\n"
