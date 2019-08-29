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

DONE=$SM/run_status/aln_4.indel_realign.done

printf -- "---\n[$(date)] Start RealignerTargetCreator.\n"

if [[ -f $DONE ]]; then
    $JAVA -Xmx58G -Djava.io.tmpdir=tmp -jar $GATK \
        -T RealignerTargetCreator -nt $NSLOTS \
        -R $REF -known $MILLS -known $INDEL1KG \
        -I $SM/alignment/$SM.markduped.bam \
        -o $SM/alignment/realigner.intervals

    printf -- "---\n[$(date)] Finish RealignerTargetCreator.\n"
    printf -- "---\n[$(date)] Start IndelRealigner.\n---\n"

    $JAVA -Xmx58G -Djava.io.tmpdir=tmp -jar $GATK \
        -T IndelRealigner \
        -R $REF -known $MILLS -known $INDEL1KG \
        -targetIntervals $SM/alignment/realigner.intervals \
        -I $SM/alignment/$SM.markduped.bam \
        -o $SM/alignment/$SM.realigned.bam
    rm $SM/alignment/$SM.markduped.{bam,bai} $SM/alignment/realigner.intervals
    touch $DONE
fi

printf -- "[$(date)] Finish IndelRealigner.\n---\n"
