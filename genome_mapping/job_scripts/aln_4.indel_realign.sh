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

printf -- "[$(date)] Start RealignerTargetCreator.\n---\n"

$JAVA -Xmx58G -Djava.io.tmpdir=tmp -jar $GATK \
    -T RealignerTargetCreator -nt 36 \
    -R $REF -known $MILLS -known $ONEKG \
    -I $SM/bam/$SM.markduped.bam \
    -o $SM/realigner.intervals

printf -- "---\n[$(date)] Finish RealignerTargetCreator.\n"
printf -- "---\n[$(date)] Start IndelRealigner.\n---\n"

$JAVA -Xmx58G -Djava.io.tmpdir=tmp -jar $GATK \
    -T IndelRealigner \
    -R $REF -known $MILLS -known $ONEKG \
    -targetIntervals $SM/realigner.intervals \
    -I $SM/bam/$SM.markduped.bam \
    -o $SM/bam/$SM.realigned.bam
rm $SM/bam/$SM.markduped.{bam,bai}

printf -- "---\n[$(date)] Finish IndelRealigner.\n"
