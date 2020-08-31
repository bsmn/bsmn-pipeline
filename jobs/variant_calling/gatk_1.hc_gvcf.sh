#!/bin/bash
#$ -cwd
#$ -pe threaded 8 

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    false
fi

SM=$1
PL=$2

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

BAM=$SM/bam/$SM.bam
GVCF=$SM/gvcf/$SM.ploidy_$PL.$CHR.g.vcf
RVCF=$SM/raw_vcf/$SM.ploidy_$PL.$CHR.vcf
RVCF_ALL=$SM/raw_vcf/$SM.ploidy_$PL.vcf
CVCF_ALL=$SM/recal_vcf/$SM.ploidy_$PL.vcf

printf -- "---\n[$(date)] Start HC_GVCF.\n"

if [[ ! -f $GVCF.idx && ! -f $RVCF.idx && ! -f $RVCF_ALL.idx && ! -f $CVCF_ALL.idx ]]; then
    mkdir -p $SM/gvcf
    $JAVA -Xmx52G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK \
        -T HaplotypeCaller \
        -R $REF \
        -I $BAM \
        --emitRefConfidence GVCF \
        -ploidy $PL \
        -nct $NSLOTS \
        -L $CHR \
        -A StrandAlleleCountsBySample \
        -o $GVCF
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish HC_GVCF.\n---\n"
