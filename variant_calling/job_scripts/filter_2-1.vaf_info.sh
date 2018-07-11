#!/bin/bash
#$ -cwd
#$ -pe threaded 1

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    exit 1
fi

source $(pwd)/run_info

set -eu -o pipefail

SM=$1
PL=$2

IN_VCF=$SM/recal_vcf/$SM.ploidy_$PL.known_germ_filtered.snvs.vcf.gz
VAF=$SM/vaf/$SM.ploidy_$PL.known_germ_filtered.pass.snvs.txt
BAM=$SM/bam/$SM.bam

printf -- "---\n[$(date)] Start generate vaf info.\n"
mkdir -p $SM/vaf

$BCFTOOLS view -H -f PASS $IN_VCF \
    |grep -v ^# |cut -f1,2,4,5 \
    |$PYTHON3 $UTIL_HOME/somatic_vaf.py -b $BAM > $VAF

printf -- "[$(date)] Finish generate vaf info.\n---\n"
