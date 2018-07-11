#!/bin/bash
#$ -cwd
#$ -pe threaded 16 

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    exit 1
fi

source $(pwd)/run_info

set -eu -o pipefail

SM=$1
PL=$2

if [[ ${SGE_TASK_ID} -le 22 ]]; then
    CHR=${SGE_TASK_ID}
elif [[ ${SGE_TASK_ID} -eq 23 ]]; then
    CHR=X
elif [[ ${SGE_TASK_ID} -eq 24 ]]; then
    CHR=Y
fi

GVCF=$SM/gvcf/$SM.ploidy_$PL.$CHR.g.vcf
RVCF=$SM/raw_vcf/$SM.ploidy_$PL.$CHR.vcf
RVCF_ALL=$SM/raw_vcf/$SM.ploidy_$PL.vcf
CVCF_ALL=$SM/recal_vcf/$SM.ploidy_$PL.vcf

printf -- "---\n[$(date)] Start Joint GT.\n"

if [[ ! -f $RVCF.idx && ! -f $RVCF_ALL.idx && ! -f $CVCF_ALL.idx ]]; then
    mkdir -p $SM/raw_vcf
    $JAVA -Xmx52G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK \
        -T GenotypeGVCFs \
        -R $REF \
        -ploidy $PL \
        -nt $NSLOTS \
        -L $CHR \
        -V $GVCF \
        -o $RVCF
    rm $GVCF $GVCF.idx
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish Joint GT.\n---\n"
