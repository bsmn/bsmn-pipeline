#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=30:00:00
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

DONE=$SM/run_status/aln_3.markdup.done

printf -- "---\n[$(date)] Start markdup.\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."

else
    mkdir -p $SM/tmp
    $GATK4 --java-options "-Xmx60G -Djava.io.tmpdir=$SM/tmp" MarkDuplicatesSpark \
        -I $SM/alignment/$SM.merged.bam \
        -O $SM/alignment/$SM.markduped.bam \
        -M $SM/alignment/markduplicates_metrics.txt \
        --optical-duplicate-pixel-distance 2500 \
        --tmp-dir $SM/tmp \
        --conf 'spark.executor.cores=16'

    rm $SM/alignment/$SM.merged.bam{,.bai}
    rm -rf $SM/tmp
    touch $DONE
fi

printf -- "[$(date)] Finish markdup.\n---\n"
