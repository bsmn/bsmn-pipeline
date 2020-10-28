#!/bin/bash
#$ -cwd
#$ -j y
#$ -V

trap "exit 100" ERR
set -e

if [[ $# -lt 2 ]]; then
    echo "Usage: $JOB_NAME [sample name] [ploidy]"
    false
fi

SM=$1
PL=$2

source $(pwd)/$SM/run_info

if [[ $SKIP_CNVNATOR == "True" ]]; then
    INPREFIX=$SM/candidates/$SM.ploidy_$PL
else
    INPREFIX=$SM/candidates/$SM.ploidy_$PL.cnv
fi
OUTVCF=$SM/candidates/$SM.ploidy_$PL.filtered.vcf

printf -- "[$(date)] Start making the final vcf file.\n"
printf -- "[INFO] Writing to $OUTVCF.\n"

# if [ $(ls -1 $INPREFIX.*.pon.txt |wc -l) -lt 1 ]; then
#     echo "ERROR:: Filtered results are not available."
#     false
# fi

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

if [[ -f $OUTVCF ]]; then
    printf -- "[OUT] Total count of filtered variants: $(grep -v ^# $OUTVCF |wc -l) \n"
fi
printf -- "---\n[$(date)] Finish making the final vcf file.\n"

