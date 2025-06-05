#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
##SBATCH --time=30:00:00
#SBATCH --time=7-00:00:00
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

DONE2=$SM/run_status/aln_4.indel_realign.2-realign.done

printf -- "---\n[$(date)] Start IndelRealigner.\n---\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the indel realign step."
else
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then
        CHRS="$(seq -s ' ' -f 'chr%g' 22) chrX chrY"
    else
        CHRS="$(seq -s ' ' 22) X Y"
    fi
    for C in $CHRS; do cat $SM/alignment/realigner.intervals.$C; done > $SM/alignment/realigner.intervals
    $GATK -Xmx12G -Djava.io.tmpdir=$SM/tmp \
        -T IndelRealigner \
        -R $REF -known $MILLS -known $INDEL1KG \
        -targetIntervals $SM/alignment/realigner.intervals \
        -I $SM/alignment/$SM.markduped.bam \
        -o $SM/alignment/$SM.realigned.bam \
        $INDEL_REALIGN_PARAMS
    rm $SM/alignment/$SM.markduped.{bam,bai}
    for C in $CHRS; do rm $SM/alignment/realigner.intervals.$C; done
    touch $DONE2
fi

rm -rf $SM/tmp

printf -- "[$(date)] Finish IndelRealigner.\n---\n"
