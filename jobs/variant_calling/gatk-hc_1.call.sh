#!/bin/bash
#$ -cwd
#$ -pe threaded 6

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) <sample name> <ploidy>"
    exit 1
fi

SM=$1
PL=$2

JXMX=$3
if [ -z $JXMX ]; then JXMX=52G; fi

source $(pwd)/$SM/run_info
export PATH=$(dirname $JAVA):$PATH

set -eu -o pipefail

if [[ ${SGE_TASK_ID} -le 22 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR="chr${SGE_TASK_ID}"; else CHR=${SGE_TASK_ID}; fi
elif [[ ${SGE_TASK_ID} -eq 23 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR=chrX; else CHR=X; fi
elif [[ ${SGE_TASK_ID} -eq 24 ]]; then
    if [ $REFVER == "hg19" -o  $REFVER == "hg38" ]; then CHR=chrY; else CHR=Y; fi
fi

DONE1=$SM/run_status/gatk-hc_1.call.ploidy_$PL.$CHR.1-gvcf.done
DONE2=$SM/run_status/gatk-hc_1.call.ploidy_$PL.$CHR.2-joint_gt.done

if [[ $FILETYPE == "fastq" ]]; then
    if [[ $ALIGNFMT == "cram" ]]; then
        IN="-I $SM/alignment/$SM.cram"
    else
        IN="-I $SM/alignment/$SM.bam"
    fi
else
    IN=$(awk -v sm="$SM" '$1 == sm {print sm"/alignment/"$2}' $SAMPLE_LIST |sed 's/^/-I /' |xargs)
fi
CHR_GVCF=$SM/gatk-hc/$SM.ploidy_$PL.$CHR.g.vcf.gz
CHR_RAW_VCF=$SM/gatk-hc/$SM.ploidy_$PL.$CHR.vcf.gz

printf -- "---\n[$(date)] Start HC_GVCF: ploidy_$PL, $CHR\n"
echo "IN: $IN"

if [[ -f $DONE1 ]]; then
    echo "Skip the gvcf step."
else
    mkdir -p $SM/gatk-hc tmp
    $GATK4 --java-options "-Xmx$JXMX -Djava.io.tmpdir=tmp -XX:-UseParallelGC" \
        HaplotypeCaller \
        --native-pair-hmm-threads $NSLOTS \
        -R $REF \
        $IN \
        -ERC GVCF \
        -ploidy $PL \
        -L $CHR \
        -A StrandBiasBySample \
        -O $CHR_GVCF
    touch $DONE1
fi

printf -- "[$(date)] Finish HC_GVCF: ploidy_$PL, $CHR\n---\n"

printf -- "---\n[$(date)] Start Joint GT: ploidy_$PL, $CHR\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the joint gt step."
else
    $GATK4 --java-options "-Xmx$JXMX -Djava.io.tmpdir=tmp -XX:-UseParallelGC" \
        GenotypeGVCFs \
        -R $REF \
        -ploidy $PL \
        -L $CHR \
        -V $CHR_GVCF \
        -O $CHR_RAW_VCF
    rm $CHR_GVCF $CHR_GVCF.tbi
    touch $DONE2
fi

printf -- "[$(date)] Finish Joint GT: ploidy_$PL, $CHR\n---\n"
