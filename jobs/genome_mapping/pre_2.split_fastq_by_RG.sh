#!/bin/bash
#$ -cwd
#$ -pe threaded 3

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <fastq> [fastq ...]"
    false
fi

FQ_L="$@"
SM=$(echo ${FQ_L[0]}|cut -d"/" -f1)

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

if [[ ${FQ_L[0]} =~ (.R1|_R1|_r1|_1)(|_001).f(|ast)q(|.gz) ]]; then
    RD=R1
else
    RD=R2
fi

DONE=$SM/run_status/pre_2.split_fastq_by_RG.$RD.done

printf -- "---\n[$(date)] Start split fastq: $RD\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    mkdir -p $SM/fastq

    for FQ in ${FQ_L[@]}; do
        if [[ $FQ == *.gz ]]; then
            CAT=zcat
        else
            CAT=cat
        fi

        $CAT $FQ
    done |paste - - - - |awk -F"\t" -v SM=$SM -v RD=$RD '{
        h=$1;
        sub(/^@/,"",h);
        sub(/ .+$/,"",h);
        l=split(h,arr,":");
        FCX=arr[l-4];
        LN=arr[l-3];
        print $1"\n"$2"\n+\n"$4|"gzip >"SM"/fastq/"SM"."FCX"_L"LN"."RD".fastq.gz"}
        END {
        print "READ N: "NR}'
    rm ${FQ_L[@]}
    touch $DONE
fi

printf -- "[$(date)] Finish split fastq: $RD\n---\n"
