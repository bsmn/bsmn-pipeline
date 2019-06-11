#!/bin/bash
#$ -cwd
#$ -pe threaded 16 

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [control sample name]"
    false
fi

SM=$1
CTR=$2

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

BAM1=$SM/bam/$SM.bam
BAM2=$SM/bam/$CTR.bam
strelka_out=$SM/strelka

printf -- "---\n[$(date)] Start Strelka paired sample mode.\n"
if [[ ! -f $VCF ]]; then
	mkdir $SM/strelka
	$STRELKA \
		--normalBam $BAM2 \
		--tumorBam $BAM1 \
		--referenceFasta $REF \
		--runDir $strelka_out
	cd $strelka_out
	$strelka_out/runWorkflow.py -m local -j 8
printf -- "[$(date)] Finish Strelka paired sample mode.\n---\n"
