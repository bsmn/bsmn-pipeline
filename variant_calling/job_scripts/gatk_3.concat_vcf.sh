#!/bin/bash
#$ -cwd
#$ -pe threaded 3

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    exit 1
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info

set -eu -o pipefail

RVCFS=""
for i in $(seq 1 22) X Y; do
    RVCFS="$RVCFS -V $SM/raw_vcf/$SM.ploidy_$PL.$i.vcf"
done
RVCF_ALL=$SM/raw_vcf/$SM.ploidy_$PL.vcf
CVCF_ALL=$SM/recal_vcf/$SM.ploidy_$PL.vcf

printf -- "---\n[$(date)] Start concat vcfs.\n"

if [[ ! -f $RVCF_ALL.idx && ! -f $CVCF_ALL.idx ]]; then
    $JAVA -Xmx6G -cp $GATK org.broadinstitute.gatk.tools.CatVariants \
        -R $REF \
        $RVCFS \
        -out $RVCF_ALL \
        -assumeSorted

    for i in $(seq 1 22) X Y; do
        rm $SM/raw_vcf/$SM.ploidy_$PL.$i.vcf
        rm $SM/raw_vcf/$SM.ploidy_$PL.$i.vcf.idx
    done
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish concat vcfs.\n---\n"
