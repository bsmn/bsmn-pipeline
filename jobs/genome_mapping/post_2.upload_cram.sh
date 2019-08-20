#!/bin/bash
#$ -cwd
#$ -pe threaded 1

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

printf -- "---\n[$(date)] Start upload: $SM.cram{,.crai}\n"

if [[ $UPLOAD = "None" ]]; then
    echo "Skip this step"
else
    cd $SM/alignment
    $SYNAPSE add --parentid $UPLOAD $SM.cram
    $SYNAPSE add --parentid $UPLOAD $SM.cram.crai
    touch upload_done

    JID=$(cat $SM/*/hold_jid|xargs|sed 's/ /,/g')
    ssh -o StrictHostKeyChecking=No $SGE_O_HOST \
        "cd $SGE_O_WORKDIR; qsub -hold_jid $JID $PIPE_HOME/jobs/genome_mapping/post_4.delete_cram.sh $SM"
fi

printf -- "[$(date)] Finish upload: $SM.cram{,.crai}\n---\n"
