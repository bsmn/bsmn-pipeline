#!/bin/bash
#$ -cwd
#$ -pe threaded 1

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [sample name]"
    exit 1
fi

SM=$1

source $(pwd)/$SM/run_info
source $ROOTSYS/bin/thisroot.sh

set -eu -o pipefail

SUM_PREFIX=$SM/bias_summary/$SM.ploidy_
CANDALL=$SM/candidates/$SM.mosaic_snvs.all.txt
CANDCNV=$SM/candidates/$SM.mosaic_snvs.cnv_considered.txt
GENOTYPE=$SM/candidates/$SM.genotype
VCF=$SM/candidates/$SM.vcf
HISROOT=$SM/cnv/$SM.his.root
BAM=$SM/bam/$SM.bam

printf -- "---\n[$(date)] Start select candidates.\n"
#rm $BAM
mkdir -p $SM/candidates

cat ${SUM_PREFIX}{3,4,5,6,7,8,9,10}.*|grep biallelic > ${SUM_PREFIX}tmp
sort -u ${SUM_PREFIX}2.* ${SUM_PREFIX}tmp \
    |grep -v -e not -e germ -e bias1.bias2 -e one_strand \
    |grep P$ \
    |awk '$12 < 1e-5 && $14 >= 0.1' \
    |sort -u -k1V -k2n -k3 > $CANDALL
rm ${SUM_PREFIX}tmp

awk '{print $1":"$2-1000"-"$2+1000} END {print "exit"}' $CANDALL \
    |$CNVNATOR -root $HISROOT -genotype 100 \
    |grep Genotype > $GENOTYPE

paste $CANDALL $GENOTYPE \
    |awk '$25 < 2.44' \
    |cut -f-21 > $CANDCNV

printf "##fileformat=VCFv4.2\n" > $VCF.tmp
printf "##FORMAT=<ID=AD,Number=.,Type=Integer,Description=\"Allelic depths for the ref and alt alleles in the order listed\">\n" >> $VCF.tmp
printf "##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n" >> $VCF.tmp
printf "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t$SM\n" >> $VCF.tmp
awk '{print $1"\t"$2"\t.\t"$3"\t"$4"\t.\t.\t.\tGT:AD\t0/1:"$6","$7}' $CANDCNV >> $VCF.tmp

$JAVA -Xmx4g -jar $PICARD SortVcf \
    CREATE_INDEX=false \
    SD=${REF/fa/dict} \
    I=$VCF.tmp O=$VCF
rm $VCF.tmp

printf -- "[$(date)] Finish select candidates.\n---\n"
