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

printf -- "---\n[$(date)] Start BQSR recal_table.\n"

$JAVA -Xmx58G -jar $GATK \
    -T BaseRecalibrator -nct $NSLOTS \
    -R $REF -knownSites $DBSNP -knownSites $MILLS -knownSites $INDEL1KG \
    -I $SM/alignment/$SM.realigned.bam \
    -o $SM/alignment/recal_data.table

printf -- "---\n[$(date)] Start BQSR recal_table.\n"
printf -- "---\n[$(date)] Start BQSR PrintReads.\n---\n"

$JAVA -Xmx58G -jar $GATK \
    -T PrintReads -nct $NSLOTS \
    --disable_indel_quals \
    -R $REF -BQSR $SM/laignment/recal_data.table \
    -I $SM/alignment/$SM.realigned.bam \
    -o $SM/alignment/$SM.bam
rm $SM/alignment/$SM.realigned.{bam,bai}

printf -- "[$(date)] Finish BQSR PrintReads.\n---\n"
