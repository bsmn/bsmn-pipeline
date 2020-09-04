#!/bin/bash
#$ -cwd
#$ -pe threaded 2
#$ -j y
#$ -l h_vmem=11G
#$ -V

trap "exit 100" ERR
set -e -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $JOB_NAME [sample name] [ploidy]"
    false
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info

IN_VCF=$SM/gatk-hc/$SM.ploidy_$PL.vcf.gz
OUT_VCF=$SM/gatk-hc/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.vcf.gz

SECONDS=0
printf -- "[$(date)] Start gnomAD filtering.\n"
printf -- "Sample: $SM \n"
printf -- "Ploidy: $PL \n---\n"
printf -- "[IN] Raw variants: $(zcat $IN_VCF | grep -v ^# | wc -l) \n"

if [[ ! -f $OUT_VCF.tbi ]]; then
    $VT decompose -s $IN_VCF \
        |$VT normalize -n -r $REF - \
        |$VT uniq - \
        |$BCFTOOLS view -v snps \
        |$PYTHON3 $PIPE_HOME/utils/germline_filter.py -V $GNOMAD_SNP \
        |$BGZIP > $OUT_VCF
    $TABIX $OUT_VCF
else
    echo "Skip this step. Already done."
fi

printf -- "[OUT] gnomAD filtered variants: $(zcat $OUT_VCF | grep -v ^# | wc -l) \n"
printf -- "---\n[$(date)] Finish gnomAD filtering.\n"
elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

