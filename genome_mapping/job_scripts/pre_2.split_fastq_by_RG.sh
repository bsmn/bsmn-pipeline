#!/bin/bash
#$ -cwd
#$ -pe threaded 3

set -eu -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [fastq]"
    exit 1
fi

source $(pwd)/run_info

FQ=$1
SM=$(echo $FQ|cut -d"/" -f1)

if [[ $FQ == *.gz ]]; then
    CAT=zcat
else
    CAT=cat
fi

if [[ $FQ =~ (.R1|_R1|_r1|_1)(|_001).f(|ast)q(|.gz) ]]; then
    RD=R1
else
    RD=R2
fi

printf -- "[$(date)] Start split fastq: $FQ\n---\n"

$CAT $FQ |paste - - - - |awk -v SM=$SM -v RD=$RD '{
    h=$1;
    sub(/^@/,"",h);
    l=split(h,arr,":");
    FCX=arr[l-4];
    LN=arr[l-3];
    print $1"\n"$2"\n+\n"$4|"gzip >"SM"/fastq/"SM"."FCX"_L"LN"."RD".fastq.gz"}'
rm $FQ

printf -- "---\n[$(date)] Finish split fastq: $FQ\n"
