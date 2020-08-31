#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    false
fi

SM=$1
PL=$2
OUTVCF=$SM/candidates/$SM.ploidy_$PL.filtered.vcf
ANNO=${OUTVCF/vcf/ann.gz}

if [ $(ls -1 $SM/candidates/$SM.ploidy_$PL.*.pon.txt |wc -l) -ne 3 ]; then
    echo "Filtered results are not available."
    exit 1;
fi

cat <(awk '{print $0, "HC"}' OFS='\t' $SM/candidates/$SM.ploidy_$PL.cnv.mosaic.hc.pon.txt) \
    <(awk '{print $0, "EXT"}' OFS='\t' \
          <(cat $SM/candidates/$SM.ploidy_$PL.cnv.mosaic{.hc,}.pon.txt |sort |uniq -u)) \
    <(awk '{print $0, "BSMN"}' OFS='\t' $SM/candidates/$SM.ploidy_$PL.cnv.mayo.pon.txt) \
    |awk 'NR==FNR {
              v=a[$1,$2,$3,$4]
              if (v=="") {
                  a[$1,$2,$3,$4]=$5
              } else {
                  a[$1,$2,$3,$4]=v","$5
              }
              next
          } {
              $5=a[$1,$2,$3,$4]
              print $1, $2, $3","$4, $3, $4, $5
          }' \
         OFS='\t' \
         - <(cat $SM/candidates/$SM.ploidy_$PL.cnv.mayo.pon.txt \
                 $SM/candidates/$SM.ploidy_$PL.cnv.mosaic.pon.txt \
                 |sort -k1,1V -k2,2g |uniq) \
   |bgzip -c >$ANNO
tabix -s1 -b2 -e2 $ANNO

bcftools view -T $ANNO \
              $SM/gatk-hc/$SM.ploidy_$PL.gnomAD_AFover0.001_filtered.snvs.vcf.gz \
|bcftools annotate -h <(echo '##INFO=<ID=MF,Number=.,Type=String,Description="Mosaic filters this variant passed. HC: MosaicForecast high confidence, EXT: MosaicForecast extra, BSMN: BSMN mosaic filters">') \
|bcftools annotate -a $ANNO -c CHROM,POS,-,REF,ALT,INFO/MF \
|grep -v "^##FILTER" \
|grep -v "^##ALT" \
|grep -v "^##GATK" \
|grep -v "^##source" \
|grep -v "^##contig=<ID=[^1-9XY]" \
|grep -v "^##bcftools" \
>$OUTVCF

rm $ANNO $ANNO.tbi

