#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
##SBATCH --time=30:00:00
#SBATCH --time=7-00:00:00
#SBATCH --array=1-24
#SBATCH --signal=USR1@60

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info
export PATH=$(dirname $JAVA):$PATH

set -o nounset
set -o pipefail

if [[ ${SLURM_ARRAY_TASK_ID} -le 22 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR="chr${SLURM_ARRAY_TASK_ID}"; else CHR=${SLURM_ARRAY_TASK_ID}; fi
elif [[ ${SLURM_ARRAY_TASK_ID} -eq 23 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR=chrX; else CHR=X; fi
elif [[ ${SLURM_ARRAY_TASK_ID} -eq 24 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR=chrY; else CHR=Y; fi
fi

DONE1=$SM/run_status/aln_5.bqsr.1-recal_table.$CHR.done

printf -- "---\n[$(date)] Start BQSR recal_table: $CHR\n---\n"

mkdir -p $SM/tmp

if [[ -f $DONE1 ]]; then
    echo "Skip the recal_table step."
else
    $GATK4 --java-options "-Xmx3G -Djava.io.tmpdir=$SM/tmp" \
        BaseRecalibrator \
        -R $REF \
        --known-sites $DBSNP \
        --known-sites $MILLS \
        --known-sites $INDEL1KG \
        -L $CHR \
        -I $SM/alignment/$SM.realigned.bam \
        -O $SM/alignment/recal_data.table.$CHR
    touch $DONE1
fi

printf -- "---\n[$(date)] Finish BQSR recal_table.\n"
