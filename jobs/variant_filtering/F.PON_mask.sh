#!/bin/bash
#$ -cwd
#$ -pe threaded 32
#$ -j y
#$ -l h_vmem=2G
#$ -V

if [ -z $NSLOTS ]; then NSLOTS=$(nproc); fi
if [ -z $JOB_NAME ]; then JOB_NAME=$(basename $0); fi

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

HG38_BED=${IN%.txt}.hg38.bed
UNMAPPED=${IN%.txt}.hg38.unmapped.bed

SECONDS=0

if [[ -s $IN ]]; then # Only if the input file is not empty
    printf -- "[IN] Variants before PON masking: $(cat $IN | wc -l) \n"
    if [[ ! -f $OUT ]]; then
        #eval "$(conda shell.bash hook)"
        #conda activate ucsc

        $LIFTOVER <(awk '{if(!($1~/^chr/)) $1="chr"$1; print $1"\t"$2-1"\t"$2"\t"$3"\t"$4}' <(sort -k1,1V -k2,2g $IN)) \
	    $HG19_TO_HG38 $HG38_BED $UNMAPPED

        #conda deactivate

        # $SAMTOOLS faidx -r <(awk '{print $1":"$3"-"$3}' $HG38_BED) $PONFA \
        #     |paste - - |cut -f2 |paste <(cut -f1,3-5 $HG38_BED) - \

        cut -f1,3-5 $HG38_BED \
        |while read CHR POS REF ALT; do
            RE="^chr([0-9]+|[XY])\\b"
            if [[ $CHR =~ $RE ]]; then
                P=$($SAMTOOLS faidx $PONFA $CHR:$POS-$POS |tail -1)
            else
                P="?"
            fi
            echo -e "$CHR\t$POS\t$REF\t$ALT\t$P"
         done > $OUT.tmp.2
        cat $OUT.tmp.2 |awk 'BEGIN { print "#chrm\tpos\tref\talt\tPON1kg" }
              { switch ($5) {
                case "*":
                    $5 = "Pass"; break
                case "R":
                    $5 = ($4 == "A" || $4 == "G") ? "Fail" : "Pass"; break
                case "Y":
                    $5 = ($4 == "C" || $4 == "T") ? "Fail" : "Pass"; break
                case "S":
                    $5 = ($4 == "G" || $4 == "C") ? "Fail" : "Pass"; break
                case "W":
                    $5 = ($4 == "A" || $4 == "T") ? "Fail" : "Pass"; break
                case "K":
                    $5 = ($4 == "G" || $4 == "T") ? "Fail" : "Pass"; break
                case "M":
                    $5 = ($4 == "A" || $4 == "C") ? "Fail" : "Pass"; break
                case "B":
                    $5 = ($4 == "C" || $4 == "G" || $4 == "T") ? "Fail" : "Pass"; break
                case "D":
                    $5 = ($4 == "A" || $4 == "G" || $4 == "T") ? "Fail" : "Pass"; break
                case "H":
                    $5 = ($4 == "A" || $4 == "C" || $4 == "T") ? "Fail" : "Pass"; break
                case "V":
                    $5 = ($4 == "A" || $4 == "C" || $4 == "G") ? "Fail" : "Pass"; break
                case "N":
                    $5 = "Fail"; break
                default:
                    $5 = "Fail"; break
                }
                print $0
              }' OFS='\t' \
        >$OUT.tmp

        if [[ -s $UNMAPPED ]]; then
            echo "The liftOver has failed for some sites."
	        echo "Check $UNMAPPED file."
            if [[ $REFVER == "hg19" ]]; then
                paste <(grep -v ^# $UNMAPPED |cut -f1,3-5 |sort |comm -23 <(sort $IN) - |sort -k1,1V -k2,2g) <(tail -n+2 $OUT.tmp |cut -f5) \
                    | awk '$5 == "Pass" {print $1,$2,$3,$4}' OFS='\t' > $OUT
            else
                paste <(grep -v ^# $UNMAPPED |cut -f1,3-5 |sed 's/^chr//' |sort |comm -23 <(sort $IN) - |sort -k1,1V -k2,2g) <(tail -n+2 $OUT.tmp |cut -f5) \
                    | awk '$5 == "Pass" {print $1,$2,$3,$4}' OFS='\t' > $OUT
            fi
        else
            paste <(sort -k1,1V -k2,2g $IN) <(tail -n+2 $OUT.tmp |cut -f5) \
                | awk '$5 == "Pass" {print $1,$2,$3,$4}' OFS='\t' > $OUT
        fi
        if [[ ! -s $OUT ]]; then
            echo "No results."
            # rm $OUT
        fi
        rm $OUT.tmp $OUT.tmp.2
    else
        echo "Skip this step. Already done."
    fi
else
    echo "$IN is empty. No results."
    cat /dev/null >$OUT
fi

if [[ $FROM == "mosaic" ]]; then
    IN2=${IN%.txt}.hc.txt
    OUT2=${IN2%.txt}.pon.txt
    if [[ -s $IN2 ]]; then
        comm -12 <(sort $IN2) <(sort $OUT) \
            |sort -k1,1V -k2,2g > $OUT2
    else
        echo "$IN2 is empty. No results."
        cat /dev/null >$OUT2
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
