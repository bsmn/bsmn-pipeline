#!/bin/bash

usage="usage: $(basename $0) -i <variants file> -v <snps or indels> <VAF file> [<VAF file> ...]"

while getopts i:v: opt; do
    case $opt in
        i) IN=$OPTARG;;
        v) VTYPE=$OPTARG;;
	?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $IN ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi

if [ -z $VTYPE ]; then
    VTYPE="snps"
elif [ $VTYPE != "snps" ] && [ $VTYPE != "indels" ]; then
    echo "[ERROR] Unknown variant type: $VTYPE" >&2 ; exit 1
fi

OUT=/tmp/$(uuidgen)
cp $IN $OUT

for V in $*; do
    SM=${V/.somatic.vaf/}; SM=${SM##*.}
    HEADER="$SM.DP\t$SM.AD\t$SM"
    grep -v ^# $IN |cut -f1-4 \
    |if [ $VTYPE = "snps" ]; then
         awk -v H="$HEADER"  -v OFS='\t' \
             'BEGIN{print H}NR==FNR{a[$1,$2,$3,$4]=$6OFS$8OFS$5;next}{$5=a[$1,$2,$3,$4];print $5}' $V -
     elif [ $VTYPE = "indels" ]; then
         awk -v H="$HEADER"  -v OFS='\t' \
             'BEGIN{print H}NR==FNR{a[$1,$2,$3,$4]=$5OFS$6OFS$7;next}{$5=a[$1,$2,$3,$4];print $5}' $V -
     fi \
    |paste -d'\t' $OUT -> $OUT.tmp
    rm $OUT; mv $OUT.tmp $OUT
done

cat $OUT; rm $OUT

