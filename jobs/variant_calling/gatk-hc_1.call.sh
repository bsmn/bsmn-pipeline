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

set -eu -o pipefail

if [[ ${SGE_TASK_ID} -le 22 ]]; then
    CHR=${SGE_TASK_ID}
elif [[ ${SGE_TASK_ID} -eq 23 ]]; then
    CHR=X
elif [[ ${SGE_TASK_ID} -eq 24 ]]; then
    CHR=Y
fi

BAM=$(ls -1 data.bam_cram/$SM.*am|sed "s/^/-I /")
CHR_GVCF=$SM/gatk-hc/$SM.ploidy_$PL.$CHR.g.vcf
CHR_RAW_VCF=$SM/gatk-hc//$SM.ploidy_$PL.$CHR.vcf
RAW_VCF=$SM/gatk-hc/$SM.ploidy_$PL.raw.vcf
RECAL_VCF=$SM/gatk-hc//$SM.ploidy_$PL.vcf

printf -- "---\n[$(date)] Start HC_GVCF.\n"
if [[ ! -f $CHR_GVCF.idx && ! -f $CHR_RAW_VCF.idx && ! -f $RAW_VCF.idx && ! -f $RECAL_VCF.idx ]]; then
    mkdir -p gvcf
    $GATK4 --java-options "-Xmx52G -Djava.io.tmpdir=tmp -XX:-UseParallelGC" \
        HaplotypeCaller \
        --native-pair-hmm-threads $NSLOTS \
        -R $REF \
        $BAM \
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

if [[ ! -f $CHR_RAW_VCF.idx && ! -f $RAW_VCF.idx && ! -f $RECAL_CVCF.idx ]]; then
    mkdir -p raw_vcf
    $GATK4 --java-options "-Xmx52G -Djava.io.tmpdir=tmp -XX:-UseParallelGC" \
        GenotypeGVCFs \
        -R $REF \
        -ploidy $PL \
        -L $CHR \
        -V $CHR_GVCF \
        -O $CHR_RAW_VCF
    rm $CHR_GVCF $CHR_GVCF.idx
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish Joint GT.\n---\n"
