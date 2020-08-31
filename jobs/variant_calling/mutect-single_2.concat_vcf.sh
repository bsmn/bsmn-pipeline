#!/bin/bash
#$ -cwd
#$ -pe threaded 3

trap "exit 100" ERR  

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    exit 1
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

CHRS="$(seq 1 22) X Y"
CHR_VCFS=""
for CHR in $CHRS; do
    CHR_VCFS="$CHR_VCFS -I $SM/mutect2-single/$SM.$CHR.vcf"
done
VCF=$SM/mutect2-single/$SM.vcf

printf -- "---\n[$(date)] Start concat vcfs.\n"

if [[ ! -f $VCF.idx ]]; then
    $GATK4 --java-options "-Xmx4G"  GatherVcfs \
        -R $REF \
        $CHR_VCFS \
        -O $VCF \

    for CHR in $CHRS; do
        rm $SM/mutect2-single/$SM.$CHR.vcf
        rm $SM/mutect2-single/$SM.$CHR.vcf.idx
    done
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish concat vcfs.\n---\n"
