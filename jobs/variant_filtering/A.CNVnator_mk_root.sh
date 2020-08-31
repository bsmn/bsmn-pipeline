#!/bin/bash
#$ -cwd
#$ -pe threaded 8
#$ -j y 
#$ -l h_vmem=4G
#$ -V

trap "exit 100" ERR
#set -eu -o pipefail
set -e -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $JOB_NAME <sample name> <BIN size>"
    exit 1
fi

SM=$1
BINSIZE=$2

source $(pwd)/$SM/run_info

if [[ $SKIP_CNVNATOR == "True" ]]; then
    echo "Skip running the CNVnator: Running with --skip-cnvnator parameter."
    exit 0
fi

if [[ $ALIGNFMT == "cram" ]]; then
    BAM=$SM/alignment/$SM.cram
else
    BAM=$SM/alignment/$SM.bam
fi
OUTDIR=$SM/cnvnator/$BINSIZE
ROOT=$OUTDIR/${SM}.root
if [[ $REFVER == "hg19" ]]; then
    CHROM="$(seq -f 'chr%g' 22) chrX chrY"
else
    CHROM="$(seq 22) X Y"
fi

SECONDS=0
printf -- "[$(date)] Start CNVnator for ${SM}.\n"
printf -- "BAM: ${BAM}\n"
printf -- "BIN size: ${BINSIZE}\n---\n"

DONE=$SM/run_status/CNVnator_mk_root.$BINSIZE.done

if [[ -f $DONE ]]; then
    echo "Skip running the CNVnator: Already done."
else
    if [[ -f $ROOT ]]; then
        rm -rf $OUTDIR
    fi
    mkdir -p $OUTDIR
    
    # $CONDA activate cnvnator
    #CONDADIR=/home/mayo/m216456/miniconda3
    #source $CONDADIR/bin/activate cnvnator
    eval "$(conda shell.bash hook)"
    conda activate cnvnator
    
    export XDG_CACHE_HOME=$PIPE_HOME/resources/$REFVER.cache
    
    cnvnator -root $ROOT -chrom $CHROM -tree $BAM -lite
    cnvnator -root $ROOT -chrom $CHROM -his $BINSIZE -d $REFDIR
    cnvnator -root $ROOT -chrom $CHROM -stat $BINSIZE
    cnvnator -root $ROOT -chrom $CHROM -partition $BINSIZE
    cnvnator -root $ROOT -chrom $CHROM -call $BINSIZE > $OUTDIR/${SM}.cnvcall
    
    #source $CONDADIR/bin/deactivate
    conda deactivate

    mkdir -p $SM/run_status
    touch $DONE
fi

printf -- "---\n[$(date)] Finish CNVnator.\n"

elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

