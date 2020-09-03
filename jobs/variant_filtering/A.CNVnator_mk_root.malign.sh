#!/bin/bash
#$ -cwd
#$ -pe threaded 8
#$ -j y 
#$ -l h_vmem=4G
#$ -V

trap "exit 100" ERR
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

BAMS=`awk -v sm="$SM" '$1 == sm {print sm"/alignment/"$2}' $SAMPLE_LIST | xargs`
OUTDIR=$SM/cnvnator/$BINSIZE
ROOT=$OUTDIR/${SM}.root
if [[ $REFVER == "hg19" ]]; then
    CHROM="$(seq -f 'chr%g' 22) chrX chrY"
else
    CHROM="$(seq 22) X Y"
fi

SECONDS=0
printf -- "[$(date)] Start CNVnator for ${SM}.\n"
printf -- "BAM files: ${BAMS}\n"
printf -- "BIN size: ${BINSIZE}\n---\n"

DONE=$SM/run_status/CNVnator_mk_root.malign.$BINSIZE.done

if [[ -f $DONE ]]; then
    echo "Skip running the CNVnator: Already done."
else
    if [[ -f $ROOT ]]; then
        rm -rf $OUTDIR
    fi
    mkdir -p $OUTDIR
    
    #eval "$(conda shell.bash hook)"
    #conda activate cnvnator
    
    export XDG_CACHE_HOME=$PIPE_HOME/resources/$REFVER.cache

    $CNVNATOR -root $ROOT -chrom $CHROM -tree $BAMS -lite
    $CNVNATOR -root $ROOT -chrom $CHROM -his $BINSIZE -d $REFDIR
    $CNVNATOR -root $ROOT -chrom $CHROM -stat $BINSIZE
    $CNVNATOR -root $ROOT -chrom $CHROM -partition $BINSIZE
    $CNVNATOR -root $ROOT -chrom $CHROM -call $BINSIZE > $OUTDIR/${SM}.cnvcall
    
    #conda deactivate

    mkdir -p $SM/run_status
    touch $DONE
fi

printf -- "---\n[$(date)] Finish CNVnator.\n"

elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

