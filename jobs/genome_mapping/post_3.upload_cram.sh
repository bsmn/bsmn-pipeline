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

DONE=$SM/run_status/post_3.upload_cram.done

printf -- "---\n[$(date)] Start upload: $SM.cram{,.crai}\n"

if [[ -f $DONE ]] || [[ $UPLOAD = "None" ]]; then
    echo "Skip this step"
else
    cd $SM/alignment
    $SYNAPSE add --parentid $UPLOAD $SM.cram  || false
    $SYNAPSE add --parentid $UPLOAD $SM.cram.crai  || false
    cd $SGE_O_WORKDIR

    JID=$(cat $SM/*/hold_jid|xargs|sed 's/ /,/g')
    ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
        "bash --login -c 'cd $SGE_O_WORKDIR; qsub -hold_jid $JID -o $SM/logs -j yes $PIPE_HOME/jobs/genome_mapping/post_4.delete_cram.sh $SM'"

    touch $DONE
fi

printf -- "[$(date)] Finish upload: $SM.cram{,.crai}\n---\n"
