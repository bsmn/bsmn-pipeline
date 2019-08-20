#!/usr/bin/env bash
#$ -cwd
#$ -pe threaded 16

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample_name> [targets.bed]"
    exit 1
fi

SM=$1

if [ -z "$2" ]; then
    mode='WGS'
    TARGETS=''
else
    mode='WES'
    TARGETS="-L ${2} -ip 50" ## pad 50 bases
fi

#source $(pwd)/$SM/run_info

set -euo pipefail

BAM=$SM/bam/$SM.bam
VCF=$SM/vcf/$SM.mutect2-raw.vcf.gz

printf -- "---\n[$(date)] Starting MuTect2 single sample calling ${mode}.\n".

if [[ ! -f $VCF ]]; then
    mkdir -p $SM/vcf
    $JAVA -Xmx32G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK4 \
        Mutect2 \
        -R $REF \
        -I $BAM \
        -tumor $SM \
        --germline-resource $GNOMAD \
        $TARGETS \
        -O $VCF \
        --disable-read-filter MateOnSameContigOrNoMappedMateReadFilter ## see https://github.com/broadinstitute/gatk/issues/3514
fi
