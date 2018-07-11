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
STR=$SM/strand/$SM.ploidy_$PL.known_germ_filtered.pass.snvs.txt
BAM=$SM/bam/$SM.bam

printf -- "---\n[$(date)] Start generate strand info.\n"
mkdir -p $SM/strand 

$BCFTOOLS view -H -f PASS $IN_VCF \
    |cut -f1,2,4,5 \
    |$PYTHON3 $UTIL_HOME/strand_bias.py -b $BAM > $STR

printf -- "[$(date)] Finish generate strand info.\n---\n"
