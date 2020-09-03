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

if [[ $# -lt 3 ]]; then
    echo "Usage: $JOB_NAME [sample name] [BAM or CRAM list file] [ploidy]"
    false
fi

SM=$1
FBAMLIST=$2
PL=$3

source $SM/run_info

SECONDS=0

printf -- "[$(date)] Start running MosaicForecast.\n"
printf -- "Sample: $SM \n"
printf -- "Ploidy: $PL \n-----\n"

SUB_SAMPLES=`awk -v sm="$SM" -v cram="$ALIGNFMT" '$1 == sm {gsub("\\\\."cram, "", $2); print $2}' $FBAMLIST`

cd $SM

if [[ $SKIP_CNVNATOR == "True" ]]; then
    IN=candidates/$SM.ploidy_$PL.txt
else
    IN=candidates/$SM.ploidy_$PL.cnv.txt
fi
BED=${IN/txt/bed}
FEATURES=${BED/bed/mosaic.features}
PREDICTION=${FEATURES/features/predictions}

# Input BED file for MosaicForecast
cut -f1-4 $IN \
    |sort -k1,1V -k2,2g \
    |awk -v sm=$SM '{print $1"\t"$2-1"\t"$2"\t"$3"\t"$4"\t"sm}' > $BED

printf -- "[$(date)] Start picking and merging ${ALIGNFMT} files.\n---\n"
printf -- "[IN] Variants fed into MosaicForecast filtering: $(cat $BED | wc -l) \n"

DONE0=run_status/MosaicForecast.malign.pick.ploidy_$PL.done

export XDG_CACHE_HOME=$PIPE_HOME/resources/$REFVER.cache

if [ -f $DONE0 ]; then
    echo "Skip this. Already done."
else
    # if [[ $(cat $BED |wc -l) -gt 2000 ]]; then
    #     PICK_RANGE=1000
    # else
    #     PICK_RANGE=10000
    # fi
    PICK_RANGE=10000
    echo "Up and downstream range around variant sites is $PICK_RANGE"
    rm -f $BED.regioned; rm -rf alignment/picked.$PL; mkdir -p alignment/picked.$PL
    awk -v PR=$PICK_RANGE '{print $1, ($2-PR), ($3+PR)}' OFS='\t' $BED > $BED.regioned
    parallel --joblog logs/$JOB_NAME.pick.o$JOB_ID -j $((NSLOTS-2)) --halt now,fail=1 \
        $SAMTOOLS view -bh -T $REF -M \
            -L $BED.regioned \
            -o alignment/picked.$PL/{}.picked.bam \
            alignment/{}.$ALIGNFMT \
        ::: $SUB_SAMPLES
    rm $BED.regioned
    parallel -j $((NSLOTS-2)) $SAMTOOLS index alignment/picked.$PL/{}.picked.bam ::: $SUB_SAMPLES
    $SAMTOOLS merge -@ $((NSLOTS-2)) -f alignment/picked.$PL/$SM.bam alignment/picked.$PL/*.picked.bam
    $SAMTOOLS index alignment/picked.$PL/$SM.bam
    rm alignment/picked.$PL/*.picked.bam{,.bai}

    mkdir -p run_status
    touch $DONE0
fi

printf -- "---\n[$(date)] Finish picking and merging ${ALIGNFMT} files.\n"

printf -- "[$(date)] Start extracting features and prediction.\n---\n"

DONE=run_status/MosaicForecast.malign.ploidy_$PL.done

if [[ -f $DONE ]]; then
    echo "Skip this. Already done."
else
    TIN=${BED/bed/mosaic.in}
    TOUT=${BED/bed/mosaic.out}
    rm -f $FEATURES $TIN $TOUT $TOUT.tmp $PREDICTION # Just in case of rerunning
    
    set +e +o pipefail
    for i in $(seq $(cat $BED|wc -l)); do
        tail -n+$i $BED |head -n1 > $TIN
        echo ">> $(cat $TIN)"
        SUCCESS=1
        RETRY=0
        while [ $SUCCESS -ne 0 -a $RETRY -lt 15 ]; do
            timeout 10 \
                python3 $MFDIR/ReadLevel_Features_extraction.py \
                    $TIN $TOUT alignment/picked.$PL \
                    $REF $MFRES/k24.umap.wg.bw 150 $((NSLOTS-2)) bam \
            && SUCCESS=0 || SUCCESS=$?
            if [ $SUCCESS -eq 124 ]; then
                rm -f core.*
                ((RETRY=$RETRY+1))
                echo "[ERROR] Failed and hanging. Retrying ..."
            elif [ $SUCCESS -ne 0 ]; then
                SUCCESS=0
                echo "[ERROR] Failed but not hanging. Skipping ..."
            fi
        done
        if [[ -s $TOUT ]]; then
            if [[ ! -s $FEATURES ]]; then
                head -n1 $TOUT > $FEATURES
            fi
            tail -n1 $TOUT >> $FEATURES
    	    rm $TOUT
        fi
        rm -f $TIN $TOUT.tmp
    done
    set -e -o pipefail
    
    if [[ -s $FEATURES ]]; then
        Rscript $MFDIR/Prediction.R $FEATURES $MFDIR/models_trained/250xRFmodel_addRMSK_Refine.rds Refine $PREDICTION
    else
        echo "No features."
    fi
    
    rm -rf tmp
    mkdir -p run_status
    touch $DONE
fi

printf -- "---\n[$(date)] Finish exctracting features and prediction.\n"
    
printf -- "[$(date)] Start selecting mosaic.\n---\n"

if [[ -s $PREDICTION ]]; then
    if [[ $SKIP_CNVNATOR == "True" ]]; then
        OUT_ALL=candidates/$SM.ploidy_$PL.mosaic.txt
    else
        OUT_ALL=candidates/$SM.ploidy_$PL.cnv.mosaic.txt
    fi
    awk '$35~/^mosaic/ {print $1}' $PREDICTION \
        |cut -f2- -d~ \
        |tr '~' '\t' \
        |sort -u -k1,1V -k2,2g > $OUT_ALL
    if [[ $SKIP_CNVNATOR == "True" ]]; then
        OUT_HC=candidates/$SM.ploidy_$PL.mosaic.hc.txt
    else
        OUT_HC=candidates/$SM.ploidy_$PL.cnv.mosaic.hc.txt
    fi
    awk '$35~/^mosaic/ && $37>=0.6 {print $1}' $PREDICTION \
        |cut -f2- -d~ \
        |tr '~' '\t' \
        |sort -u -k1,1V -k2,2g > $OUT_HC
    printf -- "[OUT] Mosaic variants predicted by MosaicForecast (All): $(cat $OUT_ALL | wc -l) \n"
    printf -- "[OUT] Mosaic variants predicted by MosaicForecast (High Confidence): $(cat $OUT_HC | wc -l) \n"
else
    echo "No predictions."
fi

printf -- "---\n[$(date)] Finish selecting mosaic.\n"

printf -- "-----\n[$(date)] Finish MosaicForecast.\n"


elapsed=$SECONDS
printf -- "\n\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."
