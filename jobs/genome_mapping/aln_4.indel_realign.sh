#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
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

DONE1=$SM/run_status/aln_4.indel_realign.1-target.done
DONE2=$SM/run_status/aln_4.indel_realign.2-realign.done

printf -- "---\n[$(date)] Start RealignerTargetCreator.\n"

mkdir -p $SM/tmp

if [[ -f $DONE1 ]]; then
    echo "Skip the target creation step."
else
    $GATK -Xmx12G -Djava.io.tmpdir=$SM/tmp \
        -T RealignerTargetCreator -nt $NSLOTS \
        -R $REF -known $MILLS -known $INDEL1KG \
        -I $SM/alignment/$SM.markduped.bam \
        -o $SM/alignment/realigner.intervals \
        $INDEL_REALIGN_PARAMS
    touch $DONE1
fi

printf -- "---\n[$(date)] Finish RealignerTargetCreator.\n"

printf -- "---\n[$(date)] Start IndelRealigner.\n---\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the indel realign step."
else
    $GATK -Xmx12G -Djava.io.tmpdir=$SM/tmp \
        -T IndelRealigner \
        -R $REF -known $MILLS -known $INDEL1KG \
        -targetIntervals $SM/alignment/realigner.intervals \
        -I $SM/alignment/$SM.markduped.bam \
        -o $SM/alignment/$SM.realigned.bam \
        $INDEL_REALIGN_PARAMS
    #rm $SM/alignment/$SM.markduped.{bam,bai} $SM/alignment/realigner.intervals
    rm $SM/alignment/$SM.markduped.{bam,bai}
    touch $DONE2
fi

rm -rf $SM/tmp

printf -- "[$(date)] Finish IndelRealigner.\n---\n"
