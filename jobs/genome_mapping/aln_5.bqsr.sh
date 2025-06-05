#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
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

set -o nounset
set -o pipefail

DONE1=$SM/run_status/aln_5.bqsr.1-recal_table.done
DONE2=$SM/run_status/aln_5.bqsr.2-apply_bqsr.done
#DONE3=$SM/run_status/aln_5.bqsr.3-indexing.done
DONE4=$SM/run_status/aln_5.bqsr.4-flagstat.done

printf -- "---\n[$(date)] Start BQSR recal_table.\n---\n"

mkdir -p $SM/tmp

if [[ -f $DONE1 ]]; then
    echo "Skip the recal_table step."
else
    $GATK4 --java-options "-Xmx12G -Djava.io.tmpdir=$SM/tmp" \
        BaseRecalibrator \
        -R $REF \
        --known-sites $DBSNP \
        --known-sites $MILLS \
        --known-sites $INDEL1KG \
        -I $SM/alignment/$SM.realigned.bam \
        -O $SM/alignment/recal_data.table
    touch $DONE1
fi

printf -- "---\n[$(date)] Finish BQSR recal_table.\n"

printf -- "---\n[$(date)] Start ApplyBQSR.\n---\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the ApplyBQSR step."
else
    if [[ $ALIGNFMT == "cram" ]]; then
        $GATK4 --java-options "-Xmx12G -Djava.io.tmpdir=$SM/tmp" \
            ApplyBQSR \
            -R $REF \
            --bqsr-recal-file $SM/alignment/recal_data.table \
            -I $SM/alignment/$SM.realigned.bam \
            |$SAMTOOLS view -@ $((NSLOTS-2)) -C -T $REF -o $SM/alignment/$SM.cram
    else
        $GATK4 --java-options "-Xmx12G -Djava.io.tmpdir=$SM/tmp" \
            ApplyBQSR \
            -R $REF \
            --bqsr-recal-file $SM/alignment/recal_data.table \
            -I $SM/alignment/$SM.realigned.bam \
            |$SAMTOOLS view -bh -o $SM/alignment/$SM.bam
            #-O $SM/alignment/$SM.bam
    fi
    rm $SM/alignment/$SM.realigned.{bam,bai}
    touch $DONE2
fi

printf -- "[$(date)] Finish ApplyBQSR.\n---\n"

#printf -- "---\n[$(date)] Start indexing: $SM.$ALIGNFMT\n"
#
#if [[ -f $DONE3 ]]; then
#    echo "Skip the indexing step."
#else
#    $SAMTOOLS index -@ $NSLOTS $SM/alignment/$SM.$ALIGNFMT
#    touch $DONE3
#fi
#
#printf -- "[$(date)] Finish indexing: $SM.$ALIGNFMT\n---\n"

printf -- "---\n[$(date)] Start flagstat: $SM.$ALIGNFMT\n"

if [[ -f $DONE4 ]]; then
    echo "Skip the flagstat step."
else
    $SAMTOOLS flagstat -@ $NSLOTS $SM/alignment/$SM.$ALIGNFMT > $SM/alignment/flagstat.txt
    touch $DONE4
fi

rm -rf $SM/tmp

printf -- "[$(date)] Finish flagstat: $SM.$ALIGNFMT\n---\n"
