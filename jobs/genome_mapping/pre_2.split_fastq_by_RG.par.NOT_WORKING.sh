#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --mem=1G
#SBATCH --time=30:00:00
#SBATCH --signal=USR1@60

NSLOTS=$SLURM_CPUS_ON_NODE

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

if [[ ${FQ_L[0]} =~ (\.R1|_R1|_r1|_1)(|_001)\.f(|ast)q(|\.gz) ]]; then
    RD=R1
else
    RD=R2
fi

DONE=$SM/run_status/pre_2.split_fastq_by_RG.$RD.done

printf -- "---\n[$(date)] Start split fastq: $RD\n"

function splitFQ {
    local FQ=$1
    local SM=$2
    local RD=$3
    if [[ $FQ == *.gz ]]; then local CAT=zcat; else local CAT=cat; fi
    $CAT $FQ |paste - - - - |awk -F"\t" -v SM=$SM -v RD=$RD '{
        if ($1 ~ /:/) {
          h=$1;
          sub(/^@/,"",h);
          sub(/ .+$/,"",h);
          l=split(h,arr,":");
          FCX=arr[l-4];
          LN=arr[l-3];
          print $1"\n"$2"\n+\n"$4|"gzip >"SM"/fastq/"SM"."FCX"_L"LN"."RD".fastq.gz"
        }
        else if ($1 ~ /[A-Z]+[0-9]+L[0-9]+C[0-9]+R[0-9]+/) {
          h=$1; match(h, /@([A-Z]+[0-9]+)L([0-9]+)/, PU);
          print $1"\n"$2"\n+\n"$4|"gzip >"SM"/fastq/"SM"."PU[1]"_L"PU[2]"."RD".fastq.gz"
        }
        else {
          print $1"\n"$2"\n+\n"$4|"gzip >"SM"/fastq/"SM".NOPU."RD".fastq.gz"
        }}
        END {print "READ N: "NR}'
}
export -f splitFQ

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    mkdir -p $SM/fastq
    echo "FQs: ${FQ_L[@]}"
    parallel -j $NSLOTS "splitFQ" {1} {2} {3} ::: ${FQ_L[@]} ::: $SM ::: $RD
    rm ${FQ_L[@]}
    touch $DONE
fi

printf -- "[$(date)] Finish split fastq: $RD\n---\n"
