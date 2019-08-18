#!/bin/bash
#$ -cwd
#$ -pe threaded 4 

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info
source $ROOTSYS/bin/thisroot.sh

set -o nounset
set -o pipefail

CRAM=$SM/alignment/$SM.cram
ROOT=$SM/cnvnator/$SM.root
CNVCALL=$SM/cnvnator/$SM.cnvcall
CHROM="$(seq 1 22) X Y"

printf -- "---\n[$(date)] Start cnvnator.\n"
mkdir -p $SM/cnvnator
export REF_CACHE=$SM/cnvnator/cache
$CNVNATOR -root $ROOT -chrom $CHROM -tree $CRAM -lite
for BINSIZE in 100 1000; do
    $CNVNATOR -root $ROOT -chrom $CHROM -his $BINSIZE -d $REFDIR
    $CNVNATOR -root $ROOT -chrom $CHROM -stat $BINSIZE
    $CNVNATOR -root $ROOT -chrom $CHROM -partition $BINSIZE
    $CNVNATOR -root $ROOT -chrom $CHROM -call $BINSIZE > $CNVCALL.bin_$BINSIZE
done

printf -- "[$(date)] Finish cnvnator.\n---\n"
