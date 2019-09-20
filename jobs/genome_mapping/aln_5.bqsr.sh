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

DONE=$SM/run_status/aln_5.bqsr.done

printf -- "---\n[$(date)] Start BQSR recal_table.\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    $JAVA -Xmx58G -jar $GATK \
        -T BaseRecalibrator -nct $NSLOTS \
        -R $REF -knownSites $DBSNP -knownSites $MILLS -knownSites $INDEL1KG \
        -I $SM/alignment/$SM.realigned.bam \
        -o $SM/alignment/recal_data.table

    printf -- "---\n[$(date)] Finish BQSR recal_table.\n"
    printf -- "---\n[$(date)] Start BQSR PrintReads.\n---\n"

    $JAVA -Xmx58G -jar $GATK \
        -T PrintReads -nct $((NSLOTS/2)) \
        --disable_indel_quals \
        -R $REF -BQSR $SM/alignment/recal_data.table \
        -I $SM/alignment/$SM.realigned.bam \
        |$SAMTOOLS view -@ $((NSLOTS/2)) -C -T $REF -o $SM/alignment/$SM.cram
    rm $SM/alignment/$SM.realigned.{bam,bai}

    printf -- "[$(date)] Finish BQSR PrintReads.\n---\n"
    printf -- "---\n[$(date)] Start indexing: $SM.cram\n"

    $SAMTOOLS index -@ $NSLOTS $SM/alignment/$SM.cram

    printf -- "[$(date)] Finish indexing: $SM.cram\n---\n"
    printf -- "---\n[$(date)] Start flagstat: $SM.cram\n"

    $SAMTOOLS flagstat -@ $NSLOTS $SM/alignment/$SM.cram > $SM/alignment/flagstat.txt
    touch $DONE
fi

printf -- "[$(date)] Finish flagstat: $SM.cram\n---\n"
