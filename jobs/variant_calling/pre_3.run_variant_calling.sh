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
    exit 100
fi

SM=$1

source $(pwd)/$SM/run_info

# Copy alignment files to $SM/alignment
if [[ $FILETYPE == "fastq" ]]; then
    echo "You need to run the alignment pipeline first?"
    exit 100
else
    awk -v sm="$SM" -v OFS='\t' '$1 == sm {print $2, $3}' $SAMPLE_LIST \
    |while read BAM LOC; do
         if [[ ! -f "$SM/alignment/$BAM" ]]; then # alignment file doesn't exist.
             echo "INFO: Linking $BAM to the alignment directory ..."
             mkdir -p $SM/alignment
             ln -sf $(readlink -f $LOC) $SM/alignment/$BAM
             if [[ $FILETYPE == "cram" ]]; then
                 ls -lh $LOC.crai &> /dev/null \
                    && ln -sf $(readlink -f $LOC.crai) $SM/alignment/$BAM.crai \
                    || ln -sf $(readlink -f ${LOC/.cram/.crai}) $SM/alignment/${BAM/.cram/.crai}
             else
                 ls -lh $LOC.bai &> /dev/null \
                    && ln -sf $(readlink -f $LOC.bai) $SM/alignment/$BAM.bai \
                    || ln -sf $(readlink -f ${LOC/.bam/.bai}) $SM/alignment/${BAM/.bam/.bai}
             fi
         fi
     done
fi

eval "$(conda shell.bash hook)"
conda activate --no-stack $CONDA_ENV

printf -- "---\n[$(date)] Start submit variant calling jobs.\n"

if [[ $RUN_GATK_HC = "False" ]] \
    && [[ $RUN_MUTECT_SINGLE = "False" ]] \
    && [[ $RUN_CNVNATOR = "False" ]]; then
    echo "Skip this step."
else
    mkdir -p $SM/run_status
    if [[ $RUN_GATK_HC = "True" ]]; then
        if [[ $MULTI_ALIGNS = "True" ]]; then
            $PYTHON3 $PIPE_HOME/jobs/submit_gatk-hc_jobs.py --queue $Q --ploidy $PLOIDY --sample-name $SM --multiple-alignments
            echo "[INFO] Submitted gatk-hc jobs for combined calling."
        else
            #ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
            #    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_gatk-hc_jobs.py --ploidy $PLOIDY --sample-name $SM'"
            $PYTHON3 $PIPE_HOME/jobs/submit_gatk-hc_jobs.py --queue $Q --ploidy $PLOIDY --sample-name $SM
            echo "[INFO] Submitted gatk-hc jobs."
        fi
    fi
    if [[ $RUN_MUTECT_SINGLE = "True" ]]; then
        #ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
        #    "bash --login -c 'cd $SGE_O_WORKDIR; $PYTHON3 $PIPE_HOME/jobs/submit_mutect-single_jobs.py --sample-name $SM'"
        $PYTHON3 $PIPE_HOME/jobs/submit_mutect-single_jobs.py --sample-name $SM
    fi
fi

conda deactivate

printf -- "[$(date)] Finish submit variant calling jobs.\n---\n"
