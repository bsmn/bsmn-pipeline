#!/bin/bash
#$ -cwd
#$ -pe threaded 36 

set -eu -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

source $(pwd)/run_info

SM=$1

printf -- "[$(date)] Start BQSR recal_table.\n---\n"

$JAVA -Xmx60G -jar $GATK \
    -T BaseRecalibrator -nct 36 \
    -R $REF -knownSites $DBSNP -knownSites $MILLS -knownSites $ONEKG \
    -I $SM/bam/$SM.realigned.bam \
    -o $SM/recal_data.table

printf -- "---\n[$(date)] Start BQSR recal_table.\n"
printf -- "---\n[$(date)] Start BQSR PrintReads.\n---\n"

$JAVA -Xmx60G -jar $GATK \
    -T PrintReads -nct 36 \
    --emit_original_quals \
    -R $REF -BQSR $SM/recal_data.table \
    -I $SM/bam/$SM.realigned.bam \
    -o $SM/bam/$SM.bam
rm $SM/bam/$SM.realigned.{bam,bai}

printf -- "---\n[$(date)] Finish BQSR PrintReads.\n"
