#!/bin/bash
#$ -cwd
#$ -pe threaded 32
#$ -j y
#$ -l h_vmem=2G
#$ -V


trap "exit 100" ERR
set -e -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $JOB_NAME [sample name] [ploidy] [from (mayo | mosaic)]"
    false
fi

SM=$1
PL=$2
FROM=$3

source $(pwd)/$SM/run_info

printf -- "[$(date)] Start PON masking for $FROM.\n"
printf -- "Sample: $SM \n"
printf -- "Ploidy: $PL \n---\n"

if [[ $SKIP_CNVNATOR == "True" ]]; then
    IN=$SM/candidates/$SM.ploidy_$PL.$FROM.txt
else
    IN=$SM/candidates/$SM.ploidy_$PL.cnv.$FROM.txt
fi
OUT=${IN%.txt}.pon.txt
#CAND_LIMIT=2000
CAND_LIMIT=100000

if [[ ! -f $IN ]]; then 
    echo "[ERROR] $IN does not exist."
    printf -- "---\n[$(date)] Finish PON mask.\n"
    exit 0
elif [[ $(cat $IN |wc -l) -gt $CAND_LIMIT ]]; then
    echo "[ERROR] Too many candidates (> $CAND_LIMIT) in $IN."
    echo "[ERROR] Something is wrong with $SM."
    printf -- "---\n[$(date)] Finish PON mask.\n"
    exit 0
else
    printf -- "[IN] Variants before PON masking: $(cat $IN | wc -l) \n"
fi

HG38_BED=${IN%.txt}.hg38.bed
UNMAPPED=${IN%.txt}.hg38.unmapped.bed

SECONDS=0

if [[ -s $IN ]]; then # Only if the input file is not empty
    if [[ ! -f $OUT ]]; then
        #CONDADIR=/home/mayo/m216456/miniconda3
        #source $CONDADIR/bin/activate ucsc
        eval "$(conda shell.bash hook)"
        conda activate ucsc

        liftOver <(awk '{if(!($1~/^chr/)) $1="chr"$1; print $1"\t"$2-1"\t"$2"\t"$3"\t"$4}' $IN) \
	    $PIPE_HOME/resources/hg19ToHg38.over.chain.gz \
	    $HG38_BED $UNMAPPED

        #source $CONDADIR/bin/deactivate
        conda deactivate
        
        export XDG_CACHE_HOME=$PIPE_HOME/resources/hg38.cache
        $PYTHON3 $PIPE_HOME/utils/PON_mask.2.py <(cut -f1,3-5 $HG38_BED) $OUT.tmp $HC_1KG_CRAMDIR $((NSLOTS-2)) \
	    2> >(grep -v "\[mpileup\] 1 samples in 1 input files" >&2)
        
        if [[ -s $UNMAPPED ]]; then
            echo "The liftOver has failed for some sites."
	    echo "Check $UNMAPPED file."
            if [[ $REFVER == "hg19" ]]; then
                paste <(grep -v ^# $UNMAPPED |cut -f1,3-5 |comm -23 $IN -) <(tail -n+2 $OUT.tmp |cut -f5) \
                    | awk '$5 == "Pass" {print $1,$2,$3,$4}' OFS='\t' > $OUT
            else
                paste <(grep -v ^# $UNMAPPED |cut -f1,3-5 |sed 's/^chr//' |comm -23 $IN -) <(tail -n+2 $OUT.tmp |cut -f5) \
                    | awk '$5 == "Pass" {print $1,$2,$3,$4}' OFS='\t' > $OUT
            fi
        else
            paste $IN <(tail -n+2 $OUT.tmp |cut -f5) \
                | awk '$5 == "Pass" {print $1,$2,$3,$4}' OFS='\t' > $OUT
        fi
        rm $OUT.tmp
    else
        echo "Skip this step. Already done."
    fi
else
    echo "$IN is empty. No results."
fi

if [[ $FROM == "mosaic" ]]; then
    IN2=${IN%.txt}.hc.txt
    OUT2=${IN2%.txt}.pon.txt
    if [[ -s $IN2 ]]; then
        comm -12 <(sort $IN2) <(sort $OUT) \
            |sort -k1,1V -k2,2g > $OUT2
    else
        echo "$IN2 is empty. No results."
    fi
fi

if [[ -f $OUT ]]; then
    printf -- "[OUT] Variants after PON masking: $(cat $OUT | wc -l) \n"
fi
if [[ $FROM == "mosaic" ]] && [[ -f $OUT2 ]]; then
    printf -- "[OUT] Variants after PON masking (High Confidence): $(cat $OUT2 | wc -l) \n"
fi
printf -- "---\n[$(date)] Finish PON mask.\n"

elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."
