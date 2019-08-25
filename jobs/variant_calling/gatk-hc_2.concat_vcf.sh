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
export PATH=$(dirname $JAVA):$PATH

set -eu -o pipefail

# CHRS="$(seq 1 22) X Y"
CHRS="22 X Y"
CHR_RAW_VCFS=""
for CHR in $CHRS; do
    CHR_RAW_VCFS="$CHR_RAW_VCFS -I $SM/gatk-hc/$SM.ploidy_$PL.$CHR.vcf.gz"
done
RAW_VCF=$SM/gatk-hc/$SM.ploidy_$PL.raw.vcf.gz
RECAL_VCF=$SM/gatk-hc/$SM.ploidy_$PL.vcf.gz

printf -- "---\n[$(date)] Start concat vcfs.\n"

if [[ ! -f $RAW_VCF.tbi && ! -f $RECAL_VCF.tbi ]]; then
    $GATK4 --java-options "-Xmx4G"  GatherVcfs \
        -R $REF \
        $CHR_RAW_VCFS \
        -O $RAW_VCF

    for CHR in $CHRS; do
        rm $SM/gatk-hc/$SM.ploidy_$PL.$CHR.vcf.gz
        rm $SM/gatk-hc/$SM.ploidy_$PL.$CHR.vcf.gz.tbi
    done

    $BCFTOOLS index --threads $((NSLOTS-1)) -t $RAW_VCF
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish concat vcfs.\n---\n"
