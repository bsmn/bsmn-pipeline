#!/bin/bash
#$ -cwd
#$ -pe threaded 16

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) <sample name> <ploidy>"
    exit 1
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info
export PATH=$(dirname $JAVA):$PATH

set -eu -o pipefail

if [[ ${SGE_TASK_ID} -le 22 ]]; then
    CHR=${SGE_TASK_ID}
elif [[ ${SGE_TASK_ID} -eq 23 ]]; then
    CHR=X
elif [[ ${SGE_TASK_ID} -eq 24 ]]; then
    CHR=Y
fi

CRAM=$SM/alignment/$SM.cram
CHR_GVCF=$SM/gatk-hc/$SM.ploidy_$PL.$CHR.g.vcf.gz
CHR_RAW_VCF=$SM/gatk-hc//$SM.ploidy_$PL.$CHR.vcf.gz
RAW_VCF=$SM/gatk-hc/$SM.ploidy_$PL.raw.vcf.gz
RECAL_VCF=$SM/gatk-hc/$SM.ploidy_$PL.vcf.gz

printf -- "---\n[$(date)] Start HC_GVCF.\n"
if [[ ! -f $CHR_GVCF.tbi && ! -f $CHR_RAW_VCF.tbi && ! -f $RAW_VCF.tbi && ! -f $RECAL_VCF.tbi ]]; then
    mkdir -p $SM/gatk-hc
    $GATK4 --java-options "-Xmx52G -Djava.io.tmpdir=tmp -XX:-UseParallelGC" \
        HaplotypeCaller \
        --native-pair-hmm-threads $NSLOTS \
        -R $REF \
        -I $CRAM \
        -ERC GVCF \
        -ploidy $PL \
        -L $CHR \
        -A StrandBiasBySample \
        -O $CHR_GVCF
else
    echo "Skip this step."
fi
printf -- "[$(date)] Finish HC_GVCF.\n---\n"

printf -- "---\n[$(date)] Start Joint GT.\n"

if [[ ! -f $CHR_RAW_VCF.tbi && ! -f $RAW_VCF.tbi && ! -f $RECAL_VCF.tbi ]]; then
    $GATK4 --java-options "-Xmx52G -Djava.io.tmpdir=tmp -XX:-UseParallelGC" \
        GenotypeGVCFs \
        -R $REF \
        -ploidy $PL \
        -L $CHR \
        -V $CHR_GVCF \
        -O $CHR_RAW_VCF
    rm $CHR_GVCF $CHR_GVCF.tbi
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish Joint GT.\n---\n"
