#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
##SBATCH --time=30:00:00
#SBATCH --time=7-00:00:00
#SBATCH --array=1-24
#SBATCH --signal=USR1@60

NSLOTS=$SLURM_CPUS_ON_NODE

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

if [ -z "$INDEL_REALIGN_PARAMS" ]; then INDEL_REALIGN_PARAMS=""; fi

set -o nounset
set -o pipefail

if [[ ${SLURM_ARRAY_TASK_ID} -le 22 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR="chr${SLURM_ARRAY_TASK_ID}"; else CHR=${SLURM_ARRAY_TASK_ID}; fi
elif [[ ${SLURM_ARRAY_TASK_ID} -eq 23 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR=chrX; else CHR=X; fi
elif [[ ${SLURM_ARRAY_TASK_ID} -eq 24 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR=chrY; else CHR=Y; fi
fi

DONE1=$SM/run_status/aln_4.indel_realign.1-target.$CHR.done

printf -- "---\n[$(date)] Start RealignerTargetCreator: $CHR\n"

mkdir -p $SM/tmp

if [[ -f $DONE1 ]]; then
    echo "Skip the target creation step."
else
    $GATK -Xmx6G -Djava.io.tmpdir=$SM/tmp \
        -T RealignerTargetCreator -nt $NSLOTS \
        -R $REF -known $MILLS -known $INDEL1KG \
        -I $SM/alignment/$SM.markduped.bam \
        -L $CHR \
        -o $SM/alignment/realigner.intervals.$CHR \
        $INDEL_REALIGN_PARAMS
    touch $DONE1
fi

printf -- "---\n[$(date)] Finish RealignerTargetCreator.\n"
