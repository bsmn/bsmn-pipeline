#!/bin/bash
#$ -cwd
#$ -pe threaded 1

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

printf -- "[$(date)] Start upload: $SM.cram{,crai} \n---\n"

cd $SM/alignment
$SYNAPSE add --parentid $PARENTID $SM.cram
$SYNAPSE add --parentid $PARENTID $SM.cram.crai
rm $SM.cram{,crai}
cd ..
rmdir downloads fastq 
touch done

printf -- "[$(date)] Finish upload: $SM.cram{,crai}\n---\n"
