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

printf -- "---\n[$(date)] Start submit variant calling jobs.\n"

if [[ $RUN_GATK_HC = "False" ]] \
    && [[ $RUN_MUTECT_SINGLE = "False" ]] \
    && [[ $RUN_CNVNATOR = "False" ]]; then
    echo "Skip this step."
else
    if [[ $RUN_GATK_HC = "True" ]]; then
        ssh -o StrictHostKeyChecking=No $SGE_O_HOST \
            "cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/variant_calling/submit_gatk-hc_jobs.py --ploidy $PLOIDY $SM"
        echo "Submitted gatk-hc jobs."
    fi
    if [[ $RUN_MUTECT_SINGLE = "True" ]]; then
        ssh -o StrictHostKeyChecking=No $SGE_O_HOST \
            "cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/variant_calling/submit_mutect-single_jobs.py $SM"

    if [[ $RUN_CNVNATOR = "True" ]]; then
        ssh -o StrictHostKeyChecking=No $SGE_O_HOST \
            "cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/variant_calling/submit_cnvnator_jobs.py $SM"
        echo "Submitted cnvnator jobs."
    fi
fi

printf -- "[$(date)] Finish submit variant calling jobs.\n---\n"
