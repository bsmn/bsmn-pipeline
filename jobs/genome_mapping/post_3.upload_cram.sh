#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=1G
##SBATCH --time=04:00:00
#SBATCH --time=30:00:00
#SBATCH --signal=USR1@60

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

DONE=$SM/run_status/post_3.upload_$ALIGNFMT.done
if [[ $ALIGNFMT == "cram" ]]; then
    INDEX_SUFFIX="crai"
else
    INDEX_SUFFIX="bai"
fi

printf -- "---\n[$(date)] Start upload: $SM.$ALIGNFMT{,.$INDEX_SUFFIX}\n"

if [[ -f $DONE ]] || [[ $UPLOAD = "None" ]]; then
    echo "Skip this step"
else
    cd $SM/alignment
    $SYNAPSE add --parentid $UPLOAD $SM.$ALIGNFMT  || false
    $SYNAPSE add --parentid $UPLOAD $SM.$ALIGNFMT.$INDEX_SUFFIX  || false
    cd $SGE_O_WORKDIR

    JID=$(cat $SM/*/hold_jid|xargs|sed 's/ /,/g')
    ssh -o StrictHostKeyChecking=no $SGE_O_HOST \
        "bash --login -c 'cd $SGE_O_WORKDIR; qsub -hold_jid $JID -o $SM/logs -j yes $PIPE_HOME/jobs/genome_mapping/post_4.delete_cram.sh $SM'"

    touch $DONE
fi

printf -- "[$(date)] Finish upload: $SM.$ALIGNFMT{,.$INDEX_SUFFIX}\n---\n"
