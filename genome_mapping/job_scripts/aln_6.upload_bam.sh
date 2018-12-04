#!/bin/bash
#$ -cwd
#$ -pe threaded 1

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

SM=$1

source $(pwd)/$SM/run_info

set -eu -o pipefail

printf -- "---\n[$(date)] Start flagstat: $SM.bam\n"

$SAMTOOLS flagstat $SM/bam/$SM.bam > $SM/flagstat.txt

printf -- "---\n[$(date)] Finish flagstat: $SM.bam\n"
printf -- "[$(date)] Start upload: $SM.{bam,bai} \n---\n"

cd $SM/bam
$SYNAPSE add --parentid $PARENTID $SM.bam
$SYNAPSE add --parentid $PARENTID $SM.bai
rm $SM.{bam,bai}
cd ..
rmdir downloads fastq bam
touch done

printf -- "[$(date)] Finish upload: $SM.{bam,bai}\n---\n"
