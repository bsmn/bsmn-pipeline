#!/bin/bash
#$ -cwd
#$ -pe threaded 6

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name> <ploidy>"
    exit 1
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info
export PATH=$(dirname $JAVA):$PATH

if [ -z $MAX_GAUSSIANS ]; then MAX_GAUSSIANS=4; fi

set -eu -o pipefail

DONE1=$SM/run_status/gatk-hc_3.vqsr.ploidy_$PL.1-recal_snp.done
DONE2=$SM/run_status/gatk-hc_3.vqsr.ploidy_$PL.2-apply_snp.done
DONE3=$SM/run_status/gatk-hc_3.vqsr.ploidy_$PL.3-recal_indel.done
DONE4=$SM/run_status/gatk-hc_3.vqsr.ploidy_$PL.4-apply_indel.done

RAW_VCF=$SM/gatk-hc/$SM.ploidy_$PL.raw.vcf.gz
RECAL_VCF_SNP=$SM/gatk-hc/$SM.ploidy_$PL.snps.vcf.gz
RECAL_VCF=$SM/gatk-hc/$SM.ploidy_$PL.vcf.gz
RECAL_SNP=$SM/gatk-hc/$SM.recalibrate_SNP.ploidy_$PL.recal
RECAL_INDEL=$SM/gatk-hc/$SM.recalibrate_INDEL.ploidy_$PL.recal
TRANCHES_SNP=$SM/gatk-hc/$SM.recalibrate_SNP.ploidy_$PL.tranches
TRANCHES_INDEL=$SM/gatk-hc/$SM.recalibrate_INDEL.ploidy_$PL.tranches

printf -- "---\n[$(date)] Start VQSR.\n" 

if [[ -f $DONE1 ]]; then
    echo "Skip the recal_snp step."
else
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
        --max-gaussians $MAX_GAUSSIANS \
        --maximum-training-variants 5000000 \
        -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
        -O $RECAL_SNP \
        --tranches-file $TRANCHES_SNP \
#        --rscript-file $RSCRIPT_SNP
    touch $DONE1
fi
if [[ -f $DONE2 ]]; then
    echo "Skip the apply_snp step."
else
    $GATK4 --java-options "-Xmx24G -XX:-UseParallelGC" \
        ApplyVQSR \
        -R $REF \
        -V $RAW_VCF \
        --mode SNP \
        -ts-filter-level 99.0 \
        --recal-file $RECAL_SNP \
        --tranches-file $TRANCHES_SNP \
        -O $RECAL_VCF_SNP
    touch $DONE2
fi
if [[ -f $DONE3 ]]; then
    echo "Skip the recal_indel step."
else
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
        --max-gaussians $MAX_GAUSSIANS \
        -O $RECAL_INDEL \
        --tranches-file $TRANCHES_INDEL \
#        --rscript-file $RSCRIPT_INDEL
    touch $DONE3
fi
if [[ -f $DONE4 ]]; then
    echo "Skip the apply_indel step."
else
    $GATK4 --java-options "-Xmx24G -XX:-UseParallelGC" \
        ApplyVQSR \
        -R $REF \
        -V $RECAL_VCF_SNP \
        --mode INDEL \
        -ts-filter-level 99.0 \
        --recal-file $RECAL_INDEL \
        --tranches-file $TRANCHES_INDEL \
        -O $RECAL_VCF

    rm  $RAW_VCF $RAW_VCF.tbi \
        $RECAL_VCF_SNP $RECAL_VCF_SNP.tbi \
        $RECAL_SNP $RECAL_SNP.idx $TRANCHES_SNP \
        $RECAL_INDEL $RECAL_INDEL.idx $TRANCHES_INDEL
    touch $DONE4
fi

rm -rf $SM/tmp

printf -- "[$(date)] Finish VQSR.\n---\n"
