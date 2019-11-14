#!/usr/bin/env bash
#$ -cwd
#$ -pe threaded 8

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample_name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

if [[ ${SGE_TASK_ID} -le 22 ]]; then
    CHR=${SGE_TASK_ID}
elif [[ ${SGE_TASK_ID} -eq 23 ]]; then
    CHR=X
elif [[ ${SGE_TASK_ID} -eq 24 ]]; then
    CHR=Y
fi

CRAM=$SM/alingment/$SM.cram
CHR_VCF=$SM/mutect-single/$SM.$CHR.vcf

printf -- "---\n[$(date)] Starting Mutect2 single sample calling.\n".

if [[ ! -f $VCF ]]; then
    mkdir -p $SM/mutect-single tmp
    $GATK4 --java-options "-Xmx26G -Djava.io.tmpdir=tmp -XX:-UseParallelGC" \
        Mutect2 \
        -R $REF \
        -I $CRAM \
        -L $CHR \
        -O $CHR_VCF \
        -tumor $SM \
        --germline-resource $GNOMAD \
        --disable-read-filter MateOnSameContigOrNoMappedMateReadFilter ## see https://github.com/broadinstitute/gatk/issues/3514
fi

printf -- "[$(date)] Finish Mutect2 single sample calling.\n---\n"
