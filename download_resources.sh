#!/usr/bin/env bash

PIPEHOME=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
RESDIR=$PIPEHOME/resources

mkdir -p $RESDIR $RESDIR/hg19 $RESDIR/hg38

# Make sure you've activated the conda environment for pipeline
eval "$(conda shell.bash hook)"
conda activate --no-stack bp

# Download and index the humnan reference genome (GRCh37 a.k.a. b37)
# You already have these files? Just copy or link them into $RESDIR/hg19 to skip to the next step.
if [[ ! -f $RESDIR/hg19/human_g1k_v37_decoy.fasta ]]; then
    gsutil -m cp gs://gatk-legacy-bundles/b37/human_g1k_v37_decoy.fasta.gz \
                 gs://gatk-legacy-bundles/b37/human_g1k_v37_decoy.dict.gz \
                 gs://gatk-legacy-bundles/b37/human_g1k_v37_decoy.fasta.amb \
                 gs://gatk-legacy-bundles/b37/human_g1k_v37_decoy.fasta.ann \
                 gs://gatk-legacy-bundles/b37/human_g1k_v37_decoy.fasta.bwt \
                 gs://gatk-legacy-bundles/b37/human_g1k_v37_decoy.fasta.pac \
                 gs://gatk-legacy-bundles/b37/human_g1k_v37_decoy.fasta.sa \
                 gs://gatk-legacy-bundles/b37/dbsnp_138.b37.vcf.gz \
                 gs://gatk-legacy-bundles/b37/Mills_and_1000G_gold_standard.indels.b37.vcf.gz \
                 gs://gatk-legacy-bundles/b37/1000G_phase1.indels.b37.vcf.gz \
                 gs://gatk-legacy-bundles/b37/1000G_omni2.5.b37.vcf.gz \
                 gs://gatk-legacy-bundles/b37/hapmap_3.3.b37.vcf.gz \
                 gs://gatk-legacy-bundles/b37/1000G_phase1.snps.high_confidence.b37.vcf.gz \
                 $RESDIR/hg19
    gunzip $RESDIR/hg19/human_g1k_v37_decoy.*.gz
    echo "Indexing ..."
    samtools faidx $RESDIR/hg19/human_g1k_v37_decoy.fasta
    for V in $RESDIR/hg19/*.b37.vcf.gz; do gunzip $V; bgzip -@ 4 ${V/.gz/}; tabix -p vcf -f $V; done
    echo "Done."
fi

# Download and index the humnan reference genome (hg38)
# You already have these files? Just copy or link them into $RESDIR/hg38 to skip to the next step.
if [[ ! -f $RESDIR/hg38/Homo_sapiens_assembly38.fasta ]]; then
    gsutil -m cp gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.fai \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.amb \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.ann \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.bwt \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.pac \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta.sa \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.dict \
                 gs://gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
                 gs://gcp-public-data--broad-references/hg38/v0/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi \
                 gs://gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz \
                 gs://gcp-public-data--broad-references/hg38/v0/1000G_phase1.snps.high_confidence.hg38.vcf.gz.tbi \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.known_indels.vcf.gz \
                 gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.known_indels.vcf.gz.tbi \
                 gs://gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz \
                 gs://gcp-public-data--broad-references/hg38/v0/1000G_omni2.5.hg38.vcf.gz.tbi \
                 gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz \
                 gs://gcp-public-data--broad-references/hg38/v0/hapmap_3.3.hg38.vcf.gz.tbi \
                 $RESDIR/hg38
    cd $RESDIR/hg38
    lftp -e 'pget -n 10 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/dbsnp_146.hg38.vcf.gz; exit'
    lftp -e 'pget -n 2 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/dbsnp_146.hg38.vcf.gz.tbi; exit'
    cd -
fi

# Download and index the humnan reference genome (UCSC hg19)
# You already have these files? Just copy or link them into $RESDIR/hg19 to skip to the next step.
if [[ ! -f $RESDIR/hg19/ucsc.hg19.fasta ]]; then
    gsutil -m cp gs://gatk-legacy-bundles/hg19/ucsc.hg19.dict \
                 gs://gatk-legacy-bundles/hg19/ucsc.hg19.fasta \
                 gs://gatk-legacy-bundles/hg19/ucsc.hg19.fasta.fai \
                 $RESDIR/hg19
    cd $RESDIR/hg19
    lftp -e 'pget -n 10 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg19/dbsnp_138.hg19.vcf.gz; exit'
    lftp -e 'pget -n 4 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg19/Mills_and_1000G_gold_standard.indels.hg19.sites.vcf.gz; exit'
    lftp -e 'pget -n 4 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg19/1000G_phase1.indels.hg19.sites.vcf.gz; exit'
    lftp -e 'pget -n 4 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg19/1000G_omni2.5.hg19.sites.vcf.gz; exit'
    lftp -e 'pget -n 4 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg19/hapmap_3.3.hg19.sites.vcf.gz; exit'
    lftp -e 'pget -n 10 -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg19/1000G_phase1.snps.high_confidence.hg19.sites.vcf.gz; exit'
    cd -
    echo "Indexing VCF files ..."
    for V in $RESDIR/hg19/*.hg19*.vcf.gz; do gunzip $V; bgzip -@ 4 ${V/.gz/}; tabix -p vcf -f $V; done
    echo "Done."
fi
if [[ ! -f $RESDIR/hg19/ucsc.hg19.fasta.bwt ]]; then bwa index $RESDIR/hg19/ucsc.hg19.fasta; fi

# Strict mask for all chromosomes from 1000 Genomes Project
if [[ ! -f $RESDIR/hg19/1KG.20141020.strict_mask.hg19_GRCh37.fa.gz ]]; then
    wget -c -P $RESDIR/hg19 https://github.com/abyzovlab/CNVnator/raw/master/ExampleData/1KG.20141020.strict_mask.hg19_GRCh37.fa.gz
    wget -c -P $RESDIR/hg19 https://github.com/abyzovlab/CNVnator/raw/master/ExampleData/1KG.20141020.strict_mask.hg19_GRCh37.fa.gz.fai
    wget -c -P $RESDIR/hg19 https://github.com/abyzovlab/CNVnator/raw/master/ExampleData/1KG.20141020.strict_mask.hg19_GRCh37.fa.gz.gzi
fi
if [[ ! -f $RESDIR/hg38/1KG.20160622.strict_mask.hg38_GRCh38.fa.gz ]]; then
    wget -c -P $RESDIR/hg38 https://github.com/abyzovlab/CNVnator/raw/master/ExampleData/1KG.20160622.strict_mask.hg38_GRCh38.fa.gz
    wget -c -P $RESDIR/hg38 https://github.com/abyzovlab/CNVnator/raw/master/ExampleData/1KG.20160622.strict_mask.hg38_GRCh38.fa.gz.fai
    wget -c -P $RESDIR/hg38 https://github.com/abyzovlab/CNVnator/raw/master/ExampleData/1KG.20160622.strict_mask.hg38_GRCh38.fa.gz.gzi
fi

# UCSC liftOver chain file (hg19->hg38)
if [[ ! -f $RESDIR/hg19ToHg38.over.chain.gz ]]; then
    wget -c -P $RESDIR http://hgdownload.cse.ucsc.edu/goldenpath/hg19/liftOver/hg19ToHg38.over.chain.gz
fi

# PON mask
if [[ ! -f $RESDIR/PON.q20q20.05.5.fa ]]; then
    cat $PIPEHOME/downloads/PON.q20q20.05.5.fa.gz.part* |bgzip -@ 4 -c -d >$RESDIR/PON.q20q20.05.5.fa
    samtools faidx $RESDIR/PON.q20q20.05.5.fa
fi

# gnomAD variants with AF > 0.001
if [[ ! -f $RESDIR/hg19/gnomAD.r2.1.1.AFover0.001.snps.txt.gz ]]; then
    cat $PIPEHOME/downloads/gnomAD.r2.1.1.AFover0.001.snps.txt.gz.part* >$RESDIR/hg19/gnomAD.r2.1.1.AFover0.001.snps.txt.gz
    tabix -p vcf -f $RESDIR/hg19/gnomAD.r2.1.1.AFover0.001.snps.txt.gz
fi

# Populate reference caches
if [[ ! -d $RESDIR/b37.cache/hts-ref ]]; then
    mkdir -p $RESDIR/b37.cache/hts-ref
    seq_cache_populate.pl -root $RESDIR/b37.cache/hts-ref $RESDIR/hg19/human_g1k_v37_decoy.fasta
fi
if [[ ! -d $RESDIR/hg19.cache/hts-ref ]]; then
    mkdir -p $RESDIR/hg19.cache/hts-ref
    seq_cache_populate.pl -root $RESDIR/hg19.cache/hts-ref $RESDIR/hg19/ucsc.hg19.fasta
fi
if [[ ! -d $RESDIR/hg38.cache/hts-ref ]]; then
    mkdir -p $RESDIR/hg38.cache/hts-ref
    seq_cache_populate.pl -root $RESDIR/hg38.cache/hts-ref $RESDIR/hg38/Homo_sapiens_assembly38.fasta
fi

# Mappability scores
if [[ ! -f $RESDIR/hg19/k24.umap.wg.bw ]]; then
    cd $RESDIR
    wget -qO- https://bismap.hoffmanlab.org/raw/hg19.umap.tar.gz |tar xvz
    fetchChromSizes hg19 > $RESDIR/hg19/hg19.chrom.sizes
    echo "Creating a bigWig file ..."
    wigToBigWig <(zcat $RESDIR/hg19/k24.umap.wg.gz) $RESDIR/hg19/hg19.chrom.sizes $RESDIR/hg19/k24.umap.wg.bw
    echo "Done."
    cd -
fi
if [[ ! -f $RESDIR/hg38/k24.umap.wg.bw ]]; then
    cd $RESDIR
    wget -qO- https://bismap.hoffmanlab.org/raw/hg38.umap.tar.gz |tar xvz
    fetchChromSizes hg38 > $RESDIR/hg38/hg38.chrom.sizes
    echo "Creating a bigWig file ..."
    wigToBigWig <(zcat $RESDIR/hg38/k24.umap.wg.gz) $RESDIR/hg38/hg38.chrom.sizes $RESDIR/hg38/k24.umap.wg.bw
    echo "Done."
    cd -
fi

conda deactivate

