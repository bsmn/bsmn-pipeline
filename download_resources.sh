#!/bin/bash

# Sources:

# GNOMAD sites
# ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/Mutect2/af-only-gnomad.raw.sites.b37.vcf.gz

# UMAP mappability score:
# https://bismap.hoffmanlab.org/raw/hg19.umap.tar.gz
# https://bismap.hoffmanlab.org/raw/hg19.umap.tar.gz

# Segmental Duplication regions (should be removed before calling all kinds of mosaics):  
# http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/genomicSuperDups.txt.gz

# Simple repeats (should be removed before calling mosaic INDELS):  
# http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/simpleRepeat.txt.gz

# Regions enriched for SNPs with >=3 haplotypes (should be removed before calling all kinds of mosaics):  
# the link seems broken
# https://raw.githubusercontent.com/parklab/MosaicForecast/master/resources/predictedhap3ormore_cluster.bed

maindir=$(dirname $(realpath $0))
resdir=$maindir/resources

function do_download() {
    wd=`pwd`
    cd $resdir
    # Synapse login
    # Ensure your credentials are in ~/.synapseConfig!
    synapse login
    # Download all resources
    synapse get syn21782062 --recursive
    cd $wd
}

if test ! -d $resdir; then
    mkdir -p $resdir
    do_download
else
    if test ! -f $resdir/SYNAPSE_METADATA_MANIFEST.tsv; then
        do_download
    fi
fi

cd $resdir


# Extract the human ref genome
test -f hs37d5.fa || gunzip hs37d5.fa.gz

# Extract all VCFs except for GNOMAD
mv af-only-gnomad.raw.sites.b37.vcf.gz{,~}
for F in *.vcf.*gz; do
    gunzip $F 2> /dev/null
done
mv af-only-gnomad.raw.sites.b37.vcf.gz{~,}

if test ! -f chr1.fa; then
# Split the ref genome by chromosome
awk '{ 
    r = match($1, "^>"); 
    if (r != 0) {
        filename = "chr"substr($1, 2, length($1))".fa"; 
        print $0 > filename;
    } 
    else {
        print $0 >> filename;
    }
}' hs37d5.fa
rm chrGL* chrhs37d5.fa chrNC_007605.fa
fi

# Exiting here; the resources below are for MosaicForecast
exit

# Download UMAP mappability score:
cd resources
wget -qO- resources https://bismap.hoffmanlab.org/raw/hg19.umap.tar.gz |tar xvz
cd ..
tools/ucsc/fetchChromSizes hg19 > resources/hg19/hg19.chrom.sizes
tools/ucsc/wigToBigWig <(zcat resources/hg19/k24.umap.wg.gz) resources/hg19/hg19.chrom.sizes resources/hg19/k24.umap.wg.bw

# Download repeat regions:
## Segmental Duplication regions (should be removed before calling all kinds of mosaics):  
wget -P resources http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/genomicSuperDups.txt.gz
gunzip resources/genomicSuperDups.txt.gz 

## Regions enriched for SNPs with >=3 haplotypes (should be removed before calling all kinds of mosaics):  
wget -P resources https://raw.githubusercontent.com/parklab/MosaicForecast/master/resources/predictedhap3ormore_cluster.bed

## Simple repeats (should be removed before calling mosaic INDELS):  
wget -P resources http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/simpleRepeat.txt.gz  
gunzip resources/simpleRepeat.txt.gz
