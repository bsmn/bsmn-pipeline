#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
##SBATCH --time=30:00:00
#SBATCH --time=7-00:00:00
#SBATCH --signal=USR1@60

NSLOTS=$SLURM_CPUS_ON_NODE

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info
export PATH=$(dirname $JAVA):$PATH

set -o nounset
set -o pipefail

DONE2=$SM/run_status/aln_5.bqsr.2-apply_bqsr.done
DONE3=$SM/run_status/aln_5.bqsr.3-flagstat.done

printf -- "---\n[$(date)] Start ApplyBQSR.\n---\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the ApplyBQSR step."
else
    if [ $REFVER == "hg19" -o $REFVER == "hg38" ]; then
        CHRS="$(seq -s ' ' -f 'chr%g' 22) chrX chrY"
    else
        CHRS="$(seq -s ' ' 1 22) X Y"
    fi
    RECAL_TABLES=""
    for CHR in $CHRS; do RECAL_TABLES="$RECAL_TABLES -I $SM/alignment/recal_data.table.$CHR"; done
    $GATK4 --java-options "-Xmx3G -Djava.io.tmpdir=$SM/tmp" \
        GatherBQSRReports \
        $RECAL_TABLES \
        --tmp-dir $SM/tmp \
        -O $SM/alignment/recal_data.table
    if [[ $ALIGNFMT == "cram" ]]; then
        $GATK4 --java-options "-Xmx3G -Djava.io.tmpdir=$SM/tmp" \
            ApplyBQSR \
            -R $REF \
            --bqsr-recal-file $SM/alignment/recal_data.table \
            -I $SM/alignment/$SM.realigned.bam \
            |$SAMTOOLS view -C -T $REF -o $SM/alignment/$SM.cram
    else
        $GATK4 --java-options "-Xmx3G -Djava.io.tmpdir=$SM/tmp -Dsamjdk.compression_level=6" \
            ApplyBQSR \
            -R $REF \
            --bqsr-recal-file $SM/alignment/recal_data.table \
            -I $SM/alignment/$SM.realigned.bam \
            -O $SM/alignment/$SM.bam
    fi
    rm $SM/alignment/$SM.realigned.{bam,bai}
    for C in $CHRS; do rm $SM/alignment/recal_data.table.$C; done
    touch $DONE2
fi

printf -- "[$(date)] Finish ApplyBQSR.\n---\n"

printf -- "---\n[$(date)] Start flagstat: $SM.$ALIGNFMT\n"

if [[ -f $DONE3 ]]; then
    echo "Skip the flagstat step."
else
    $SAMTOOLS flagstat -@ $NSLOTS $SM/alignment/$SM.$ALIGNFMT > $SM/alignment/flagstat.txt
    touch $DONE3
fi

rm -rf $SM/tmp

printf -- "[$(date)] Finish flagstat: $SM.$ALIGNFMT\n---\n"
