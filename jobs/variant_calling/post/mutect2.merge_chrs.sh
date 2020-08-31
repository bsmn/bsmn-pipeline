#!/bin/bash
#$ -cwd
#$ -pe threaded 1
#$ -j y
#$ -l h_vmem=4G
#$ -V

trap "exit 100" ERR

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) <mutect2 out dir> <chromosome names>"
    false
fi

OUTDIR=$1
CHRS=$2
PAIR=$(basename $OUTDIR)

printf -- "---\n[$(date)] Start merging VCF files at $1.\n"

zcat $OUTDIR/$PAIR.$(echo $CHRS |cut -f1 -d ' ').mutect.vcf.gz |grep "#" > $OUTDIR/tmp.vcf
zcat $OUTDIR/$PAIR.*.mutect.vcf.gz |grep -v "#" >> $OUTDIR/tmp.vcf
bcftools sort -O z -o $OUTDIR/$PAIR.mutect.vcf.gz $OUTDIR/tmp.vcf
bcftools index -t $OUTDIR/$PAIR.mutect.vcf.gz
rm $OUTDIR/tmp.vcf
rm $OUTDIR/$PAIR.*.mutect.vcf.{gz,gz.tbi,idx}

printf -- "---\n[$(date)] Finished merging VCF files.\n"
