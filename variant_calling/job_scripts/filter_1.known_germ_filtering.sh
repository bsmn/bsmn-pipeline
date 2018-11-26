#!/bin/bash
#$ -cwd
#$ -pe threaded 8 

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    exit 1
fi

source $(pwd)/run_info

set -eu -o pipefail

SM=$1
PL=$2

IN_VCF=$SM/recal_vcf/$SM.ploidy_$PL.vcf
OUT_VCF=$SM/recal_vcf/$SM.ploidy_$PL.known_germ_filtered.snvs.vcf.gz

printf -- "---\n[$(date)] Start known_germ_filtered_snvs.\n"

if [[ ! -f $OUT_VCF.tbi ]]; then
    $VT decompose -s $IN_VCF \
        |$VT normalize -n -r $REF - \
        |$VT uniq - \
        |$BCFTOOLS view -v snps \
        |$PYTHON3 $PIPE_HOME/utils/germline_filter.py -V $KNOWN_GERM_SNP \
        |$BGZIP > $OUT_VCF
    $TABIX $OUT_VCF
else
    echo "Skip this step."
fi

printf -- "[$(date)] Finish known_germ_filtered_snvs.\n---\n"
