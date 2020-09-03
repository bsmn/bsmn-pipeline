#!/bin/bash
#$ -cwd
#$ -pe threaded 2
#$ -j y 
#$ -l h_vmem=11G
#$ -V

trap "exit 100" ERR
#set -eu -o pipefail
set -e -o pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $JOB_NAME <sample name> <ploidy> <BIN size>"
    exit 1
fi

SM=$1
PL=$2
BINSIZE=$3

source $(pwd)/$SM/run_info

if [[ $SKIP_CNVNATOR == "True" ]]; then
    echo "Skip CNV genotyping: Running with --skip-cnvnator parameter."
    exit 0
fi

OUTDIR=$SM/cnvnator/$BINSIZE
ROOT=$OUTDIR/${SM}.root
CAND=$SM/candidates/$SM.ploidy_$PL.txt
CAND_CNV=$SM/candidates/$SM.ploidy_$PL.cnv.txt

SECONDS=0
printf -- "[$(date)] Start CNVnator genotyping\n"
printf -- "Sample: $SM \n"
printf -- "Ploidy: $PL \n---\n"
printf -- "[IN] Variants before CNV genotype filtering: $(cat $CAND | wc -l) \n"

mkdir -p $OUTDIR

if [[ ! -f $OUTDIR/${SM}.ploidy_$PL.genotype ]]; then
    #eval "$(conda shell.bash hook)"
    #conda activate cnvnator
    
    awk '{print $1":"$2-1000"-"$2+1000} END {print "exit"}' $CAND \
    	|$CNVNATOR -root $ROOT -genotype $BINSIZE \
    	|grep Genotype > $OUTDIR/${SM}.ploidy_$PL.genotype
    
    #conda deactivate
else
    echo "Skip CNV genotyping: Already done."
fi

paste $CAND $OUTDIR/${SM}.ploidy_$PL.genotype \
	|awk '$9 < 2.5' \
	|cut -f-5 > $CAND_CNV

printf -- "[OUT] Variants after CNV genotype filtering: $(cat $CAND_CNV | wc -l) \n"
printf -- "---\n[$(date)] Finish CNVnator genotyping.\n"

elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

