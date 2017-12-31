#!/bin/bash
#$ -cwd
#$ -pe threaded 1

set -eu -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

source $(pwd)/run_info

SM=$1

printf -- "[$(date)] Start upload: $SM.{bam,bai} \n---\n"

cd $SM/bam
$SYNAPSE add --parentid $PARENTID $SM.bam
$SYNAPSE add --parentid $PARENTID $SM.bai
rm $SM.{bam,bai}
cd ..
rmdir downloads fastq bam
touch done

printf -- "---\n[$(date)] Finish upload: $SM.{bam,bai}\n"
