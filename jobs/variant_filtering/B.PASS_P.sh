#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=12G
#SBATCH --time=24:00:00
#SBATCH --signal=USR1@60

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

IN_VCF=$SM/gatk-hc/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.vcf.gz
MASK=$SM/gatk-hc/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.PASS.mask.txt
OUT=$SM/gatk-hc/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.PASS.P.txt

SECONDS=0
printf -- "[$(date)] Start PASS and P bases filtering.\n"
printf -- "Sample: $SM \n"
printf -- "Ploidy: $PL \n---\n"
printf -- "[IN] gnomAD filtered variants: $(zcat $IN_VCF | grep -v ^# | wc -l) \n"

if [[ ! -f $OUT ]]; then
    printf "#chr\tpos\tref\talt\tmask\n" > $MASK
    $BCFTOOLS view -H -f PASS $IN_VCF \
        |cut -f1,2,4,5 \
        |awk -v samtools=$SAMTOOLS -v mask=$MASK1KG -v rver=$REFVER '{
    if (rver == "hg19") sub("^chr", "", $1);
    cmd=samtools" faidx "mask" "$1":"$2"-"$2"|tail -n1";
    cmd|getline mask_base;
    close(cmd);
    if (rver == "hg19") sub("^", "chr", $1);
    print $1"\t"$2"\t"$3"\t"$4"\t"mask_base
    }' >> $MASK
    
    awk '$5 == "P" {print $1"\t"$2"\t"$3"\t"$4}' $MASK > $OUT
else
    echo "Skip this step. Already done."
fi

printf -- "[OUT] PASS and P variants: $(cat $OUT | wc -l) \n"
printf -- "---\n[$(date)] Finish PASS and P bases filtering.\n"
elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

