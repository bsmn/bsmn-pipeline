#!/bin/bash
#$ -cwd
#$ -pe threaded 8

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name> <ploidy>"
    exit 1
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info

set -eu -o pipefail

RAW_VCF=$SM/gatk-hc/$SM.ploidy_$PL.raw.vcf
RECAL_VCF_SNP=$SM/gatk-hc/$SM.ploidy_$PL.snps.vcf
RECAL_VCF=$SM/gatk-hc/$SM.ploidy_$PL.vcf
RECAL_SNP=$SM/gatk-hc/$SM.recalibrate_SNP.ploidy_$PL.recal
RECAL_INDEL=$SM/gatk-hc/$SM.recalibrate_INDEL.ploidy_$PL.recal
TRANCHES_SNP=$SM/gatk-hc/$SM.recalibrate_SNP.ploidy_$PL.tranches
TRANCHES_INDEL=$SM/gatk-hc/$SM.recalibrate_INDEL.ploidy_$PL.tranches
# RSCRIPT_SNP=$SM/gatk-hc/$SM.recalibrate_SNP_plots.ploidy_$PL.R
# RSCRIPT_INDEL=$SM/gatk-hc/$SM.recalibrate_INDEL_plots.ploidy_$PL.R

printf -- "---\n[$(date)] Start VQSR.\n" 

if [[ ! -f $CVCF_ALL.idx ]]; then
    mkdir -p vqsr recal_vcf

    $GATK4 --java-options "-Xmx24G -XX:-UseParallelGC" \
        VariantRecalibrator \
        -R $REF \
        -V $RAW_VCF \
        --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP \
        --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI \
        --resource:1000G,known=false,training=true,truth=false,prior=10.0 $SNP1KG \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP \
        -an DP \
        -an QD \
        -an FS \
        -an SOR \
        -an MQ \
        -an MQRankSum \
        -an ReadPosRankSum \
        --mode SNP \
        --max-gaussians 4 \
        -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
        -O $RECAL_SNP \
        --tranches-file $TRANCHES_SNP \
#        --rscript-file $RSCRIPT_SNP

    $GATK4 --java-options "-Xmx24G -XX:-UseParallelGC" \
        ApplyVQSR \
        -R $REF \
        -V $RAW_VCF \
        --mode SNP \
        -ts-filter-level 99.0 \
        --recal-file $RECAL_SNP \
        --tranches-file $TRANCHES_SNP \
        -O $RECAL_VCF_SNP

    $GATK4 --java-options "-Xmx24G -XX:-UseParallelGC" \
        VariantRecalibrator \
        -R $REF \
        -V $RECAL_VCF_SNP \
        -resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS \
        -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP \
        -an QD \
        -an DP \
        -an FS \
        -an SOR \
        -an MQRankSum \
        -an ReadPosRankSum \
        --mode INDEL \
        -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
        --max-gaussians 4 \
        -O $RECAL_INDEL \
        --tranches-file $TRANCHES_INDEL \
#        --rscript-file $RSCRIPT_INDEL

    $GATK4 --java-options "-Xmx24G -XX:-UseParallelGC" \
        ApplyVQSR \
        -R $REF \
        -V $RECAL_VCF_SNP \
        --mode INDEL \
        -ts-filter-level 99.0 \
        --recal-file $RECAL_INDEL \
        --tranches-file $TRANCHES_INDEL \
        -O $RECAL_VCF

    rm  $RAW_VCF $RAW_VCF.idx \
        $RECAL_VCF_SNP $RECAL_VCF_SNP.idx \
        $RECAL_SNP $RECAL_INDEL \
        $TRANCHES_SNP $TRANCHES_INDEL
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish VQSR.\n---\n"
