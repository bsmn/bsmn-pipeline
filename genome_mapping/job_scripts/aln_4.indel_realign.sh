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

printf -- "---\n[$(date)] Start RealignerTargetCreator.\n"

$JAVA -Xmx58G -Djava.io.tmpdir=tmp -jar $GATK \
    -T RealignerTargetCreator -nt $NSLOTS \
    -R $REF -known $MILLS -known $INDEL1KG \
    -I $SM/bam/$SM.markduped.bam \
    -o $SM/realigner.intervals

printf -- "---\n[$(date)] Finish RealignerTargetCreator.\n"
printf -- "---\n[$(date)] Start IndelRealigner.\n---\n"

$JAVA -Xmx58G -Djava.io.tmpdir=tmp -jar $GATK \
    -T IndelRealigner \
    -R $REF -known $MILLS -known $INDEL1KG \
    -targetIntervals $SM/realigner.intervals \
    -I $SM/bam/$SM.markduped.bam \
    -o $SM/bam/$SM.realigned.bam
rm $SM/bam/$SM.markduped.{bam,bai} $SM/realigner.intervals

printf -- "[$(date)] Finish IndelRealigner.\n---\n"
