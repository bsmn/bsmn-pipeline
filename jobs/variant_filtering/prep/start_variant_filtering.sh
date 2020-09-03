#!/bin/bash
#$ -cwd
#$ -pe threaded 1

trap "exit 100" ERR

set -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

eval "$(conda shell.bash hook)"
conda activate $CONDA_ENV

printf -- "[$(date)] Start submitting variant filtering jobs.\n---\n"

if [[ $RUN_FILTERS = "False" ]]; then
    echo "Skip this step. --run-filters option is not set."
else
    mkdir -p $SM/run_status
    if [[ $MULTI_ALIGNS = "False" ]]; then
        $PYTHON3 $PIPE_HOME/jobs/submit_filtering_jobs.py --queue $Q --ploidy $PLOIDY --sample-name $SM --sample-list $SAMPLE_LIST
        echo "---"
        echo "Submitted filtering jobs with single alignment."
    else
        $PYTHON3 $PIPE_HOME/jobs/submit_filtering_jobs.py --queue $Q --ploidy $PLOIDY --sample-name $SM --sample-list $SAMPLE_LIST --multiple-alignments
        echo "---"
        echo "Submitted filtering jobs with multiple alignments."
    fi
fi

conda deactivate

printf -- "---\n[$(date)] Finish submitting variant filtering jobs.\n"

