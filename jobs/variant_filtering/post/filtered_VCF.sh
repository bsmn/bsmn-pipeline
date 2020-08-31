#!/bin/bash

usage="usage: $(basename $0) -p <ploidy> [-C] <sample name>"

while getopts Cp: opt; do
    case $opt in
        C) WITHOUT_CNV=true;;
        p) PL=$OPTARG;;
        ?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $PL ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi

SM=$1
if [ -z $WITHOUT_CNV ]; then
    INPREFIX=$SM/candidates/$SM.ploidy_$PL.cnv
else
    INPREFIX=$SM/candidates/$SM.ploidy_$PL
fi
OUTVCF=$SM/candidates/$SM.ploidy_$PL.filtered.vcf

if [ $(ls -1 $INPREFIX.*.pon.txt |wc -l) -lt 1 ]; then
    echo "Filtered results are not available."
    exit 1;
fi

cat <(awk '{print $0, "HC"}' OFS='\t' $INPREFIX.mosaic.hc.pon.txt) \
    <(awk '{print $0, "EXT"}' OFS='\t' \
          <(cat $INPREFIX.mosaic{.hc,}.pon.txt |sort |uniq -u)) \
    <(awk '{print $0, "PASS"}' OFS='\t' $INPREFIX.mayo.pon.txt) \
    |awk 'NR==FNR {
              f = filters[$1, $2, $3, $4]
              filters[$1, $2, $3, $4] = (f == "") ? $5 : f";"$5
              next
          } {
              if ($1 ~ /^#/) print $0
              else {
                  $7 = filters[$1, $2, $4, $5]
                  if ($7 != "") print $0
              }
          }' OFS='\t' \
         - <(zcat $SM/gatk-hc/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.vcf.gz) \
    |grep -v "^##FILTER" \
    |grep -v "^##ALT" \
    |grep -v "^##GATK" \
    |grep -v "^##source" \
    |grep -v "^##contig=<ID=[^1-9XY]" \
    |grep -v "^##bcftools" \
    |sed '2i##FILTER=<ID=PASS,Description=“Passed common and extra filters“>' \
    |sed '3i##FILTER=<ID=HC,Description=“Passed common filters and MosaicFocast high confidence”>' \
    |sed '4i##FILTER=<ID=EXT,Description=“Passed common filters and MosaicFocast extended”>' \
>$OUTVCF

