# bsmn_pipeline
BSMN common data processing pipeline

# Setup and installation
This pipeline can be run in any cluster system using SGE job scheduler. I would recommend set your own cluster in AWS using AWS ParallelCluster.

## AWS ParallelCluster
For installing and setting up `parallelcluster`, please see the [`Getting Started Guide`](https://aws-parallelcluster.readthedocs.io/en/latest/getting_started.html) for AWS ParallelCluster.

## Installing pipeline
Clone this repository where you want it installed in your cluster. If you work with an m5.large type AWS EC2 instance we recommend the file systems mounted at `/shared` or `/efs`.
```
$ cd /shared
$ git clone https://github.com/bsmn/bsmn_pipeline
```

Install software dependencies into `bsmn_pipeline/tools` running the following script.
```
$ cd bsmn_pipeline
$ ./install_tools.sh
```

Download required resource files including the reference sequence. This step require a synapse account that can access to the Synapse page syn17062535.
```
$ ./download_resources.sh
```

## Extra set up for SGE
The pipeline require a parallel environment named "threaded" in  your SGE system. If your SGE system doen't have this parallel environment, you should add it into yours.
```
$ cat >threaded.conf <<END
pe_name            threaded
slots              99999
user_lists         NONE
xuser_lists        NONE
start_proc_args    NONE
stop_proc_args     NONE
allocation_rule    \$pe_slots
control_slaves     FALSE
job_is_first_task  TRUE
urgency_slots      min
accounting_summary TRUE
qsort_args         NONE
END
```
```
$ sudo su
# qconf -Ap threaded.conf
# qconf -mattr queue pe_list threaded all.q
```

# Usage
## genome_mapping
Run the pipeline using a wrapper shell script.
```bash
genome_mapping.sh sample_list.txt
```

### sample_list.txt format
The lines starting with # will be commented out and ignored. The header line should start with # as well. Eg.
```
#sample_id	file_name	location
5154_brain-BSMN_REF_brain-534-U01MH106876	bulk_sorted.bam	syn10639574
5154_fibroblast-BSMN_REF_fibroblasts-534-U01MH106876	fibroblasts_sorted.bam	syn10639575
5154_NeuN_positive-BSMN_REF_NeuN+_E12-677-U01MH106876	E12_MDA_common_sorted.bam	s3://nda-bsmn/abyzova_1497485007384/data/E12_MDA_common_sorted.bam
5154_NeuN_positive-BSMN_REF_NeuN+_C12-677-U01MH106876	C12_MDA_common_sorted.bam	/efs/data/C12_MDA_common_sorted.bam
```
The "location" column can be a Synape ID, S3Uri of the NDA or a user, or LocalPath. For Data download, synapse or aws clients, or symbolic lins will be used, respectively.

### options
```
--parentid syn123
```
With parentid option, you can specify a Synapse ID of project or folder where to upload result bam files. If it is set, the result bam files will be uploaded into Synapse and deleted. Otherwise, they will be locally kept.

# Contributing

The `master` branch is protected. To make introduce changes:

1. Fork this repository
2. Open a branch with your github username and a short descriptive statement (like `kdaily-update-readme`). If there is an open issue on this repository, name your branch after the issue (like `kdaily-issue-7`).
3. Open a pull request and request a review.

# Versions

## v1.10 (installfix)

This version fixes broken URLs in the previous versions of `install_tools.sh` and `download_resources.sh` that prevented installing or fetching the dependencies of the pipeline.

To deal with the impermanence of URLs pointing to some of the dependencies the "installfix" branch of development gathered all resources and stored them on Synapse in a single folder called [bsmn-pipeline-dependencies](https://www.synapse.org/#!Synapse:syn21782058) (syn21782058).  Under this main folder, actually, resources and tools have been stored in their corresponding subfolders (resources: syn21782062, tools: syn21782261).  `install_tools.sh` and `download_resources.sh` now needs to refer only to the bsmn-pipeline-dependencies Synapse folder and its two subfolders instead of many volatile URLs pointing to individual tools/resources.

The `install_tools.sh` and `download_resources.sh` scripts have been successfully tested under Amazon Linux AMI 2018.03 and Ubuntu 18.04.4 LTS (both for the desktop and server edition).  It was also tested under Debian GNU/Linux 10 (buster) but some of the tools failed to build from source when invoking `install_tools.sh`.

### TODOs

* The following tools are currently omitted from `install_tools.sh` due to issues with building from source (mostly under Ubuntu 18.04.4 LTS)
    1. [cnvnator](https://github.com/abyzovlab/CNVnator) is currently excluded because its dependency [root](https://root.cern.ch/) framework failed to build from source
    1. R and MosaicForecast
    1. Perl
    1. exonerate
* Some resources for MosaicForecast are currently missing from `download_resources.sh`.
* Test alignment and variant calling with GATK HaplotypeCaller and update documentation
* Implement variant calling with MuTect2.  This will likely use Sentieon Tools' TNhapoltyper, which the faster reimplementation of GATK's original MuTect2 implementation
* Implement filtering the raw callsets of HaplotypeCaller MuTect2 by either or both of the following alternatives
    1. the BSMN best practices heuristic filters
    1. MosaicForecast



# The present script was used for that operation.  Its usage is as follows:
#
# > dependencies_to_synapse.py maindir synapseParentID
#
# "maindir" is the path to a local directory with its resources and tools
# subdirectories, each containing dependencies packaged in file archives.
# "synapseParentID" is the Synapse project or folder where the
# bsmn-pipeline-dependencies Synapse folder will be created with its own
# resources and tools Synapse subfolders.
#
# maindir
# |--resources
# |--tools

## v1.00

This version was used by Taejeong Bae to produce the first batch of AWS cloud based results for the entire BSMN consortium.  Its two main functionalities are:
* alignment of reads to the hs37d5 reference genome to produce BAM and/or CRAM files
* calling somatic variants with GATK HaplotypeCaller in its polyploid mode
