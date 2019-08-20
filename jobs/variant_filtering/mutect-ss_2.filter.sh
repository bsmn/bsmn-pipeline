#!/usr/bin/env bash
#$ -cwd
#$ -pe threaded 16

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample_name> [targets.bed]"
    exit 1
fi

SM=$1

if [ -z "$2" ]; then
    mode='WGS'
    TARGETS=''
else
    mode='WES'
    TARGETS="-L ${2} -ip 50" ## pad 50 bases
fi

source $(pwd)/$SM/run_info

set -euo pipefail
mkdir -p $SM/tmp

BAM="$SM/bam/${SM}.bam"
VCF_RAW="$SM/vcf/${SM}.mutect2-raw.vcf.gz"
PILEUP_SUMMARIES="$SM/tmp/${SM}.pileup_summaries.table"
CONTAMINATION="$SM/tmp/${SM}.contamination.table"
VCF_ONEPASS="$SM/tmp/${SM}.mutect2-onepass.vcf.gz"
ARTIFACT_PREFIX="$SM/tmp/${SM}.artifact"
ARTIFACTS="${ARTIFACT_PREFIX}.pre_adapter_detail_metrics.txt"
VCF_ALLFILTERS="$SM/vcf/${SM}.mutect2-allfilters.vcf.gz"
VCF_FINAL="$SM/vcf/${SM}.mutect2-filt.vcf.gz"

if [[ -f $VCF_FINAL ]]; then
  echo "$VCF_FINAL exists. Nothing to be done."
  exit 0
fi

printf -- "---\n[$(date)] {SM}: Filtering Mutect2 calls for ${mode}.\n"

## get pileup summaries
if [[ ! -f $PILEUP_SUMMARIES ]]; then
    echo "Getting pileup summaries."
    $JAVA -Xmx32G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK4 \
        GetPileupSummaries \
        -I $BAM \
        -V $GNOMAD \
        $TARGETS \
        -O $PILEUP_SUMMARIES \
        --verbosity DEBUG
fi

## calculate contamination
if [[ ! -f $CONTAMINATION ]]; then
    echo "Calculating contamination."
    $JAVA -Xmx32G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK4 \
        CalculateContamination \
        -I $PILEUP_SUMMARIES \
        -O $CONTAMINATION \
        --verbosity DEBUG
fi

## apply first pass filters
if [[ ! -f $VCF_ONEPASS ]]; then
    echo "Filtering first pass."
    $JAVA -Xmx32G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK4 \
        FilterMutectCalls \
        -V $VCF_RAW \
	--reference $REF \
        --contamination-table $CONTAMINATION \
        -O $VCF_ONEPASS \
        --verbosity DEBUG
fi

## calculate artifact metrics
if [[ ! -f $ARTIFACTS ]]; then
    echo "Calculating sequencing artifact metrics."
    $JAVA -Xmx32G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK4 \
        CollectSequencingArtifactMetrics \
        -I $BAM \
        -O $ARTIFACT_PREFIX \
        --FILE_EXTENSION ".txt" \
        -R $REF
fi

## filter orientation bias
if [[ ! -f $VCF_ALLFILTERS ]]; then
    echo "Filtering for orientation bias."
    $JAVA -Xmx32G -Djava.io.tmpdir=tmp -XX:-UseParallelGC -jar $GATK4 \
        FilterByOrientationBias \
        -AM G/T \
        -V $VCF_ONEPASS \
        -P $ARTIFACTS \
        -O $VCF_ALLFILTERS
fi

## filter for PASS only
if [[ ! -f $VCF_FINAL ]]; then
  echo "Filtering ${VCF_ALLFILTERS} for passed variants to ${VCF_FINAL}."
  zcat $VCF_ALLFILTERS | grep '^#\|PASS' | $BGZIP -c > $VCF_FINAL
  sleep 5
  $TABIX $VCF_FINAL
fi

## clean up
if [ $? -eq 0 ]; then
  rm $SM/tmp/*
fi
