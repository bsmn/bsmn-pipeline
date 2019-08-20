#!/bin/bash
#$ -cwd
#$ -pe threaded 3

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) <sample name> <ploidy>"
    exit 1
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info

set -eu -o pipefail

CHR_RAW_VCFS=""
for CHR in $(seq 1 22) X Y; do
    CHR_RAW_VCFS="$CHR_RAW_VCFS -I $SM/gatk-hc/$SM.ploidy_$PL.$CHR.vcf"
done
RAW_VCF=$SM/gatk-hc/$SM.ploidy_$PL.raw.vcf
RECAL_VCF=$SM/gatk-hc/$SM.ploidy_$PL.vcf

printf -- "---\n[$(date)] Start concat vcfs.\n"

if [[ ! -f $RAW_VCF.idx && ! -f $RECAL_VCF.idx ]]; then
    $GATK4 --java-options "-Xmx4G"  GatherVcfs \
        -R $REF \
        $CHR_RAW_VCFS \
        -O $RAW_VCF

    for CHR in $(seq 1 22) X Y; do
        rm $SM/gatk-hc/$SM.ploidy_$PL.$CHR.vcf
        rm $SM/gatk-hc/$SM.ploidy_$PL.$CHR.vcf.idx
    done
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish concat vcfs.\n---\n"
