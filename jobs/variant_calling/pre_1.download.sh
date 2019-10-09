#!/bin/bash
#$ -cwd
#$ -pe threaded 8

trap "exit 100" ERR

if [[ $# -lt 3 ]]; then
    echo "Usage: $(basename $0) <sample name> <file name> <location>"
    false
fi

SM=$1
FNAME=$2
LOC=$3

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

mkdir -p $SM/run_status
DONE=$SM/run_status/pre_1.download.$FNAME.done

printf -- "---\n[$(date)] Start download: $FNAME\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    mkdir -p $SM/alignment

    rc=0
    n=0
    until [[ $n -eq 5 ]]; do
        printf "[$(date)] Download try $n starts.\n\n"
        if [[ $LOC =~ ^syn[0-9]+ ]]; then
            $SYNAPSE get $LOC --downloadLocation $SM/alignment/ && { rc=$?; break; } || rc=$?
        elif [[ $LOC =~ ^s3:.+ ]]; then
            $AWS s3 ls $LOC || {
                printf "[$(date)] Set an NDA AWS token\n\n"
                eval "$($PIPE_HOME/utils/nda_aws_token.sh -r ~/.nda_credential)"
            }
            $AWS s3 cp --no-progress $LOC $SM/alignment/ && { rc=$?; break; } || rc=$?
        else
            ls -lh $LOC && ln -sf $(readlink -f $LOC) $SM/alignment/$FNAME || rc=$?
            break
        fi
        n=$((n+1))
        printf "[$(date)] Download try $n failed.\n\n"
    done
    [[ $rc -eq 0 ]] || false
    rm -f $SM/alignment/$FNAME.*
    touch $DONE
fi

printf -- "[$(date)] Finish downlaod: $FNAME\n---\n"
