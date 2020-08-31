#!/bin/bash
#$ -cwd
#$ -pe threaded 1
#$ -j y
#$ -o logs
#$ -l h_vmem=4G
#$ -V

trap "exit 100" ERR

usage="usage: $(basename $0) -m <mutect2 dir> -s <strelka2 dir> -v <snps or indels> [-f <AF cutoff> -d <min depth> -r <regions>] <out dir>"

while getopts m:s:f:d:r:v: opt; do
    case $opt in
        m) MUTECT2_OUT=$OPTARG;;
        s) STRELKA2_OUT=$OPTARG;;
        f) AF=$OPTARG;;
        d) DP=$OPTARG;;
        r) REGIONS=$OPTARG;;
        v) VTYPE=$OPTARG;;
    ?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $MUTECT2_OUT ] || [ -z $STRELKA2_OUT ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi

if [ -z $AF ]; then AF=0.0; fi
if [ -z $VTYPE ]; then VTYPE=snps; fi

echo "AF: $AF, VTYPE: $VTYPE"

MERGED_OUT=$1
mkdir -p $MERGED_OUT
mkdir -p $MERGED_OUT/vcf

for D in $(ls -d $MUTECT2_OUT/*); do
    PAIR=${D##*/}
    OUT=$MERGED_OUT/$PAIR.txt
    if [ -f $OUT ]; then continue; fi
    echo $PAIR
    V1=$D/$PAIR.mutect.vcf.gz
    V2=$STRELKA2_OUT/$PAIR/$PAIR.strelka.vcf.gz
    if [ -z $REGIONS ]; then
        if [[ $(zgrep -v '^#' $V1 | head -1) =~ ^chr ]]; then
            REGIONS=`seq -s, -fchr%g 1 22`,chrX,chrY
        else
            REGIONS=`seq -s, 1 22`,X,Y
        fi
    fi
    if [ -z $DP ]; then
        cat <(bcftools norm -t $REGIONS -m -any  $V1 \
              |bcftools view -H -v $VTYPE -f PASS -i "FORMAT/AF[0]>=$AF" \
              |cut -f1,2,4,5) \
            <(bcftools norm -r $REGIONS -m -any  $V2 |bcftools view -H -v $VTYPE -f PASS \
              |cut -f1,2,4,5) \
            |sort | uniq -d |sort -k1,1V -k2,2g \
            >$OUT
    else
        cat <(bcftools norm -t $REGIONS -m -any  $V1 \
              |bcftools view -H -v $VTYPE -f PASS -i "FORMAT/AF[0]>=$AF & MIN(DP)>=$DP" \
              |cut -f1,2,4,5) \
            <(bcftools norm -r $REGIONS -m -any  $V2 |bcftools view -H -v $VTYPE -f PASS \
              |cut -f1,2,4,5) \
            |sort | uniq -d |sort -k1,1V -k2,2g \
            >$OUT
    fi
    bcftools view -T <(cut -f1,2 $OUT) -v $VTYPE $V1 > $MERGED_OUT/vcf/$PAIR.vcf
done
