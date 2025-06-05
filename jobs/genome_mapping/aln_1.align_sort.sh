#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
##SBATCH --time=30:00:00
#SBATCH --time=7-00:00:00
#SBATCH --signal=USR1@60

NSLOTS=$SLURM_CPUS_ON_NODE

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [PU info]"
    false
fi

SM=$1
PU=$2

source $(pwd)/$SM/run_info

set -o nounset 
set -o pipefail
#set -x

DONE=$SM/run_status/aln_1.align_sort.$PU.done

printf -- "---\n[$(date)] Start align_sort.\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    mkdir -p $SM/alignment $SM/tmp
    $BWA mem -M -t $((NSLOTS - 5)) \
        -R "@RG\tID:$SM.$PU\tSM:$SM\tPL:illumina\tLB:$SM\tPU:$PU" \
        $REF $SM/fastq/$SM.$PU.R{1,2}.fastq.gz \
        |$SAMBAMBA view -S -f bam -l 0 /dev/stdin \
        |$SAMBAMBA sort -m 6GB -t 4 -o $SM/alignment/$SM.$PU.sorted.bam --tmpdir=$SM/tmp /dev/stdin 
    rm $SM/fastq/$SM.$PU.R{1,2}.fastq.gz
    touch $DONE
fi

printf -- "[$(date)] Finish align_sort.\n---\n"
