#!/bin/bash
#$ -cwd
#$ -pe threaded 8

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    false
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

RVCF=$SM/raw_vcf/$SM.ploidy_$PL.vcf
CVCF_SNP=$SM/recal_vcf/$SM.ploidy_$PL.snps.vcf
CVCF_ALL=$SM/recal_vcf/$SM.ploidy_$PL.vcf
RECAL_SNP=$SM/vqsr/recalibrate_SNP.ploidy_$PL.recal
RECAL_INDEL=$SM/vqsr/recalibrate_INDEL.ploidy_$PL.recal
TRANCHES_SNP=$SM/vqsr/recalibrate_SNP.ploidy_$PL.tranches
TRANCHES_INDEL=$SM/vqsr/recalibrate_INDEL.ploidy_$PL.tranches
RSCRIPT_SNP=$SM/vqsr/recalibrate_SNP_plots.ploidy_$PL.R
RSCRIPT_INDEL=$SM/vqsr/recalibrate_INDEL_plots.ploidy_$PL.R

printf -- "---\n[$(date)] Start VQSR.\n" 

if [[ ! -f $CVCF_ALL.idx ]]; then
    mkdir -p $SM/vqsr $SM/recal_vcf

    $JAVA -Xmx24G -XX:-UseParallelGC -jar $GATK \
        -T VariantRecalibrator \
        -R $REF \
        -input $RVCF \
        -resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP \
        -resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI \
        -resource:1000G,known=false,training=true,truth=false,prior=10.0 $SNP1KG \
        -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP \
        -an DP \
        -an QD \
        -an FS \
        -an SOR \
        -an MQ \
        -an MQRankSum \
        -an ReadPosRankSum \
        -mode SNP \
        -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
        -recalFile $RECAL_SNP \
        -tranchesFile $TRANCHES_SNP \
        -rscriptFile $RSCRIPT_SNP

    $JAVA -Xmx24G -XX:-UseParallelGC -jar $GATK \
        -T ApplyRecalibration \
        -R $REF \
        -input $RVCF \
        -mode SNP \
        --ts_filter_level 99.0 \
        -recalFile $RECAL_SNP \
        -tranchesFile $TRANCHES_SNP \
        -o $CVCF_SNP

    $JAVA -Xmx24G -XX:-UseParallelGC -jar $GATK \
        -T VariantRecalibrator \
        -R $REF \
        -input $CVCF_SNP \
        -resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS \
        -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP \
        -an QD \
        -an DP \
        -an FS \
        -an SOR \
        -an MQRankSum \
        -an ReadPosRankSum \
        -mode INDEL \
        -tranche 100.0 -tranche 99.9 -tranche 99.0 -tranche 90.0 \
        --maxGaussians 4 \
        -recalFile $RECAL_INDEL \
        -tranchesFile $TRANCHES_INDEL \
        -rscriptFile $RSCRIPT_INDEL

    $JAVA -Xmx24G -XX:-UseParallelGC -jar $GATK \
        -T ApplyRecalibration \
        -R $REF \
        -input $CVCF_SNP \
        -mode INDEL \
        --ts_filter_level 99.0 \
        -recalFile $RECAL_INDEL \
        -tranchesFile $TRANCHES_INDEL \
        -o $CVCF_ALL

    rm  $RVCF $RVCF.idx \
        $CVCF_SNP $CVCF_SNP.idx \
        $RECAL_SNP $RECAL_SNP.idx \
        $RECAL_INDEL $RECAL_INDEL.idx
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish VQSR.\n---\n"
