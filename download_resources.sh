#!/bin/bash

mkdir -p resources

# Synapse login
tools/python/3.6.2/bin/synapse login --remember-me

# Download and index the human ref genome
tools/python/3.6.2/bin/synapse get syn10347383 --downloadLocation resources/
gunzip resources/hs37d5.fa.gz
tools/bwa/0.7.16a/bin/bwa index resources/hs37d5.fa
tools/samtools/1.7/bin/samtools faidx resources/hs37d5.fa
tools/java/jdk1.8.0_222/bin/java -jar tools/picard/2.12.1/picard.jar \
    CreateSequenceDictionary R=resources/hs37d5.fa O=resources/hs37d5.dict

# Download mapping resources
tools/python/3.6.2/bin/synapse get syn17062535 -r --downloadLocation resources/
gunzip resources/*vcf.gz resources/*vcf.idx.gz
rm resources/SYNAPSE_METADATA_MANIFEST.tsv

## Download GATK gnomAD
wget -P resources ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/Mutect2/af-only-gnomad.raw.sites.b37.vcf.gz
wget -P resources ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/Mutect2/af-only-gnomad.raw.sites.b37.vcf.gz.tbi


# Split the ref genome by chromosome
awk '{ 
    r = match($1, "^>"); 
    if (r != 0) {
        filename = "resources/chr"substr($1, 2, length($1))".fa"; 
        print $0 > filename;
    } 
    else {
        print $0 >> filename;
    }
}' resources/hs37d5.fa
rm resources/chrGL* resources/chrhs37d5.fa resources/chrNC_007605.fa


# Download UMAP mappability score:
wget -P resources https://bismap.hoffmanlab.org/raw/hg19.umap.tar.gz  
tar -zxvf resources/hg19.umap.tar.gz
tools/fetchChromSizes resources/hg19 > resources/hg19/hg19.chrom.sizes
tools/wigToBigWig <(zcat resources/hg19/k24.umap.wg.gz) resources/hg19/hg19.chrom.sizes resources/hg19/k24.umap.wg.bw

# Download repeat regions:
## Segmental Duplication regions (should be removed before calling all kinds of mosaics):  
wget -P resources http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/genomicSuperDups.txt.gz
gunzip resources/genomicSuperDups.txt.gz 

## Regions enriched for SNPs with >=3 haplotypes (should be removed before calling all kinds of mosaics):  
wget -P resources https://raw.githubusercontent.com/parklab/MosaicForecast/master/resources/predictedhap3ormore_cluster.bed

## Simple repeats (should be removed before calling mosaic INDELS):  
wget -P resources http://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/simpleRepeat.txt.gz  
gunzip resources/simpleRepeat.txt.gz





