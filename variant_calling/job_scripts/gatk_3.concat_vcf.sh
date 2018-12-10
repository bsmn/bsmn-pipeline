#!/bin/bash
#$ -cwd
#$ -pe threaded 3

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
