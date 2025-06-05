#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --signal=USR1@60

#$ -cwd
#$ -pe threaded 32
#$ -j y
#$ -l h_vmem=2G
#$ -V

NSLOTS=$SLURM_CPUS_ON_NODE

trap "exit 100" ERR
set -eu -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $JOB_NAME [sample name] [ploidy]"
    false
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info

IN=$SM/gatk-hc/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.PASS.P.txt
VAF=$SM/vaf/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.PASS.P.vaf
if [[ $FILETYPE == "fastq" ]]; then
    BAM=$SM/alignment/$SM.$ALIGNFMT
else
    BAM=`awk -v sm="$SM" '$1 == sm {print sm"/alignment/"$2}' $SAMPLE_LIST |head -1`
fi

SECONDS=0

printf -- "[$(date)] Start generating VAF info. \n"
printf -- "Sample: $SM \n"
printf -- "Ploidy: $PL \n"
printf -- "BAM: ${BAM}\n---\n"
printf -- "[IN] Variants before VAF filtering: $(cat $IN | wc -l) \n"

mkdir -p $SM/vaf

DONE=$SM/run_status/VAF_filters.calculation.ploidy_$PL.done

if [[ -f $DONE ]]; then
    echo "Skip calculating VAF. Already done."
else
    if [[ $REFVER == "hg19" ]]; then
        export XDG_CACHE_HOME=$PIPE_HOME/resources/hg19.cache
    else
        export XDG_CACHE_HOME=$PIPE_HOME/resources/b37.cache
    fi
    $PYTHON3 $PIPE_HOME/utils/somatic_vaf.2.py -q 20 -Q 20 -b $BAM -r $REFVER -c $CONDA_ENV -n $((NSLOTS-2)) $IN > $VAF

    mkdir -p $SM/run_status
    touch $DONE
fi

printf -- "---\n[$(date)] Finish generating VAF info.\n"



printf -- "\n[$(date)] Start VAF filtering.\n---\n"

CAND=$SM/candidates/$SM.ploidy_$PL.txt
mkdir -p $SM/candidates

#awk '$9 < 1e-6 && ($5 >= 0.02 || $8 >= 5) {print $1"\t"$2"\t"$3"\t"$4"\t"$5}' $VAF > $CAND
awk '($9 < 1e-6) && ($8 >= 5) {print $1"\t"$2"\t"$3"\t"$4"\t"$5}' $VAF > $CAND

printf -- "[OUT] Variants after VAF filtering: $(cat $CAND | wc -l) \n"
printf -- "---\n[$(date)] Finish VAF filtering.\n"

elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."
