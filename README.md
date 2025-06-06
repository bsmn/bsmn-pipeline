[![DOI](https://zenodo.org/badge/115846048.svg)](https://zenodo.org/badge/latestdoi/115846048)

# bsmn\_pipeline
BSMN common data processing pipeline implementing various SGE (Sun Grid Engine) jobs arranged for genome alignment, variant calling and filtering.

# Setup and installation
This pipeline can be run in any cluster system using SLURM job scheduler. 

## Installing pipeline
Clone this repository where you want it installed in your cluster. If you work with an m5.large type AWS EC2 instance we recommend the file systems mounted at `/shared` or `/efs`.
```bash
cd /shared
git clone https://github.com/bsmn/bsmn_pipeline
```

Create a [conda](https://docs.conda.io/en/latest/miniconda.html) environment from YAML file to install software dependencies running the following commands.
By default, the name of environment will be `bp`. you can change it by adding a `-n your_name` option.
```bash
conda env create -f /path/to/pipeline/environment.yml
```
Instead you can use a different YAML file for a version-fixed conda environment where major tools for alignment and variant calling are frozen with their exact versions we used in BSMN data analyses as follows:
* bwa 0.7.17
* picard 2.17.4
* GATK3 3.7
* GATK4 4.1.2

By default, the name of frozen environment will be `bp_frozen`.
```bash
conda env create -f /path/to/pipeline/environment_frozen.yml
```

Install ucsc-\* software packages.
```bash
conda install -n bp -c bioconda ucsc-fetchchromsizes ucsc-bigwigaverageoverbed ucsc-wigtobigwig ucsc-liftover
# If you are on bp_frozen
conda install -n bp_frozen -c bioconda ucsc-fetchchromsizes ucsc-bigwigaverageoverbed ucsc-wigtobigwig ucsc-liftover
```

Due to license restrictions, you need to download a copy of GATK3 from the Broad Institute.
```bash
conda activate bp # Make sure you've activated the environment you are working on.
wget -qO- https://storage.googleapis.com/gatk-software/package-archive/gatk/GenomeAnalysisTK-3.8-1-0-gf15c1c3ef.tar.bz2 \
     |tar xj --strip=1 */GenomeAnalysisTK.jar
gatk3-register GenomeAnalysisTK.jar
rm GenomeAnalysisTK.jar # Once register, you can delete the downloaded file.
```
If you are on the frozen environment (`bp_frozen`), you should download a copy of verion 3.7.
```bash
conda activate bp_frozen # Make sure you've activated the environment you are working on.
wget -qO- https://storage.googleapis.com/gatk-software/package-archive/gatk/GenomeAnalysisTK-3.7-0-gcfedb67.tar.bz2 \
     |tar xj GenomeAnalysisTK.jar
gatk-register GenomeAnalysisTK.jar # Not gatk3-register here.
rm GenomeAnalysisTK.jar
```

Install [MosaicForecast](https://github.com/parklab/MosaicForecast).
```bash
cd /path/to/conda/environment # Optional, any directory would be ok if you set it properly in config.ini
git clone https://github.com/parklab/MosaicForecast.git
```
Then, you should checkout the specific revision (`63d8e60`) as following:
```bash
cd MosaicForecast
git checkout 63d8e60
```

## Downloading resources
Download all required resource files including the human reference sequences. This step would take some time to complete.
```bash
cd /path/to/pipeline
./download_resources.sh
```

The following reference and resource data will be downloaded from the [GATK resource bundle](https://gatk.broadinstitute.org/hc/en-us/articles/360035890811-Resource-bundle) repository.
* Human reference sequences, along with fai and dict files for b37/hg19 and GRCh38/hg38 reference builds. 
* dbSNP in VCF.
* HapMap genotypes and sites VCF.
* OMNI 2.5 genotypes for 1000 Genomes samples, as well as sites, VCF.
* Best set of known indels to be used for local realignment.
  * 1000 Genomes Phase I indel calls.
  * Mills and 1000G gold standard indels.
* 1000G phase 1 for genotype refinement.

The following resource files for variant filtering will be downloaded from our github repository.
* One merged file that contains [genome hg19 strict mask for all chromosomes from 1000 Genomes Project](ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/supporting/accessible_genome_masks/StrictMask) (`1KG.20141020.strict_mask.hg19_GRCh37.fa.gz`)
* One merged file that contains [genome hg38 strict mask for all chromosomes from 1000 Genomes Project](http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000_genomes_project/working/20160622_genome_mask_GRCh38) (`1KG.20160622.strict_mask.hg38_GRCh38.fa.gz`)
* [gnomAD](https://gnomad.broadinstitute.org) variants with population AF > 0.001
* Panel Of Normal (PON) mask

# Usage
You don't need to manually activate the conda environment before running the pipeline. It will be taken care of by the pipeline. All commands below should be running in the directory where you want to get results.

## Configuring pipeline
If you changed any locations of tools or resources, you need to set them properly in following config files for each reference genome.
```
/path/to/pipeline/config.{b37,h19,h38}.ini
```

## sample\_list.txt format
The lines starting with # will be commented out and ignored.
If you have fastq files,
```
#sample_id    file_name                       location (full path)
FVLT          FVLT_S15_L003_R1_001.fastq.gz   /path/to/FVLT_S15_L003_R1_001.fastq.gz
FVLT          FVLT_S15_L003_R2_001.fastq.gz   /path/to/FVLT_S15_L003_R2_001.fastq.gz
```
If you have cram (or bam) files,
```
#sample_id    file_name       location (full path)
AN02255       AN02255.cram    /path/to/AN02255.cram
```

## Genome mapping
Align fastq files to a reference genome to make a aligned cram, an ummapped bam and flagstats.
```bash
python3 /path/to/pipeline/jobs/run_genome_mapping.py \
        -q your_queue \
        --sample-list /path/to/sample_list.txt
```
If you are going to use the frozen conda environment, you need to set `-n bp_frozen`.
### options
```
-q, --queue        specify the SGE queue for jobs to be submitted.
-n, --conda-env    specify the name of conda environment (default: bp)
-t, --target-seq   enable targeted sequencing mode to skip mark duplication.
-f, --align-fmt    specify alignment format (cram|bam). Default is cram.
-r, --reference    specify reference genome (b37|hg19|hg38). Default is b37 (GRCh37).
--sample-list      specify sample_list.txt file
-p, --run-gatk-hc  once alignment complete, run the variant calling with the given ploidy options.
--run-filters      once variant calling complete, run the varinat filtering as well.
```

## Variant calling
If you've already done aligning, you can run from the variant calling pipeline.
Given the BAM file, run the GATK4 HaplotypeCaller with the given ploidy options.
```bash
python3 /path/to/pipeline/jobs/run_variant_calling.py \
        -q your_queue \
        -p 2 12 50 \
        --sample-list /path/to/sample_list.txt
```
If you are going to use the frozen conda environment, you need to set `-n bp_frozen`.
### options
```
-q, --queue        specify the SGE queue for jobs to be submitted.
-n, --conda-env    specify the name of conda environment (default: bp)
-f, --align-fmt    specify alignment format (cram|bam). Default is cram.
-r, --reference    specify reference genome (b37|hg19|hg38). Default is b37 (GRCh37).
--sample-list      specify sample_list.txt file
-p, --run-gatk-hc  specify ploidy options used by GATK.
--run-filters      once variant calling complete, run the varinat filtering as well.
```

## Variant filtering
If you've already done aligning and calling variants, you can run from the variant filtering pipeline. In such case, you need to specify a directory where your existing vcf files are using -v (--vcf-directory) option.
VCF and index file names should be formed as follows:
```
<sample name>.ploidy_<ploidy>.vcf.gz
<sample name>.ploidy_<ploidy>.vcf.gz.tbi
```
Given the BAM and VCF files, run the variant filtering.
```bash
python3 /path/to/pipeline/jobs/run_variant_filtering.py \
        -q your_queue \
        -p 50 \
        --sample-list /path/to/sample_list.txt
```
### options
```
-q, --queue          specify the SGE queue for jobs to be submitted.
-n, --conda-env      specify the name of conda environment (default: bp)
-f, --align-fmt      specify alignment format (cram|bam). Default is cram.
-r, --reference      specify reference genome (b37|hg19|hg38). Default is b37 (GRCh37).
--sample-list        specify sample_list.txt file
-p, --run-gatk-hc    specify ploidy options used by GATK.
--skip-cnvnator      skip the CNV filering
-v, --vcf-directory  If you have VCF files elsewhere, specify the directory where VCF files are.
```

# Contributing

The `master` branch is protected. To make introduce changes:

1. Fork this repository
2. Open a branch with your github username and a short descriptive statement (like `kdaily-update-readme`). If there is an open issue on this repository, name your branch after the issue (like `kdaily-issue-7`).
3. Open a pull request and request a review.
