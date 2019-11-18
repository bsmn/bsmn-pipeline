#!/bin/bash
#$ -cwd
#$ -pe threaded 24

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
DONE2=$SM/run_status/aln_5.bqsr.2-print_reads.done
DONE3=$SM/run_status/aln_5.bqsr.3-indexing.done
DONE4=$SM/run_status/aln_5.bqsr.4-flagstat.done

printf -- "---\n[$(date)] Start BQSR recal_table.\n---\n"

if [[ -f $DONE1 ]]; then
    echo "Skip the recal_table step."
else
    $JAVA -Xmx58G -jar $GATK \
        -T BaseRecalibrator -nct $NSLOTS \
        -R $REF -knownSites $DBSNP -knownSites $MILLS -knownSites $INDEL1KG \
        -I $SM/alignment/$SM.realigned.bam \
        -o $SM/alignment/recal_data.table
    touch $DONE1
fi

printf -- "---\n[$(date)] Finish BQSR recal_table.\n"

printf -- "---\n[$(date)] Start BQSR PrintReads.\n---\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the print_reads step."
else
    $JAVA -Xmx58G -jar $GATK \
        -T PrintReads -nct $((NSLOTS/2)) \
        --disable_indel_quals \
        -R $REF -BQSR $SM/alignment/recal_data.table \
        -I $SM/alignment/$SM.realigned.bam \
        |$SAMTOOLS view -@ $((NSLOTS/2)) -C -T $REF -o $SM/alignment/$SM.cram
    rm $SM/alignment/$SM.realigned.{bam,bai}
    touch $DONE2
fi

printf -- "[$(date)] Finish BQSR PrintReads.\n---\n"

printf -- "---\n[$(date)] Start indexing: $SM.cram\n"

if [[ -f $DONE3 ]]; then
    echo "Skip the indexing step."
else
    $SAMTOOLS index -@ $NSLOTS $SM/alignment/$SM.cram
    touch $DONE3
fi

printf -- "[$(date)] Finish indexing: $SM.cram\n---\n"

printf -- "---\n[$(date)] Start flagstat: $SM.cram\n"

if [[ -f $DONE4 ]]; then
    echo "Skip the flagstat step."
else
    $SAMTOOLS flagstat -@ $NSLOTS $SM/alignment/$SM.cram > $SM/alignment/flagstat.txt
    touch $DONE4
fi

printf -- "[$(date)] Finish flagstat: $SM.cram\n---\n"
