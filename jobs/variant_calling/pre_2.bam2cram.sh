#!/bin/bash
#$ -cwd
#$ -pe threaded 4

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <sample name>"
    false
fi

SM=$1

source $(pwd)/$SM/run_info

set -o nounset
set -o pipefail

# Copy alignment files to $SM/alignment
if [[ $FILETYPE == "fastq" ]]; then
    echo "You need to run the alignment pipeline first?"
    exit 100
else
    awk -v sm="$SM" -v OFS='\t' '$1 == sm {print $2, $3}' $SAMPLE_LIST |head -1 \
    |while read BAM LOC; do
         if [[ ! -f "$SM/alignment/$BAM" ]]; then # alignment file doesn't exist.
             echo "Linking alignment files to the sample directory ..."
             mkdir -p $SM/alignment
             ln -sf $(readlink -f $LOC) $SM/alignment/$BAM
             if [[ $FILETYPE == "cram" ]]; then
                 ls -lh $LOC.crai &> /dev/null \
                    && ln -sf $(readlink -f $LOC.crai) $SM/alignment/$BAM.crai \
                    || ln -sf $(readlink -f ${LOC/.cram/.crai}) $SM/alignment/${BAM/.cram/.crai}
             else
                 ls -lh $LOC.bai &> /dev/null \
                    && ln -sf $(readlink -f $LOC.bai) $SM/alignment/$BAM.bai \
                    || ln -sf $(readlink -f ${LOC/.bam/.bai}) $SM/alignment/${BAM/.bam/.bai}
             fi
         fi
     done
fi

DONE1=$SM/run_status/pre_2.bam2cram.1-sam.done
DONE2=$SM/run_status/pre_2.bam2cram.2-cram.done
DONE3=$SM/run_status/pre_2.bam2cram.3-index.done

BAM=$SM/alignment/$SM.bam
SAM=$SM/alignment/$SM.sam
CRAM=$SM/alignment/$SM.cram

printf -- "---\n[$(date)] Start bam2cram: $BAM\n"

if [[ -f $DONE1 ]]; then
    echo "Skip the sam generation step."
else
    [[ -f $SAM ]] && rm $SAM
    $SAMBAMBA view -t $NSLOTS -h $BAM > $SAM
    # rm $SM/alignment/$SM.ba*
    touch $DONE1
fi

if [[ -f $DONE2 ]]; then
    echo "Skip the cram generation step."
else
    mkdir -p $SM/tmp
    parallel --tmpdir $SM/tmp -a $SAM -j $((NSLOTS-2)) -k --pipepart \
        'sed "s/\tB[ID]\:Z\:[^\t]*//g;s/\tOQ\:Z\:[^\t]*//"' \
        |$SAMTOOLS view -@ $((NSLOTS-6)) -C -T $REF -o $CRAM
    rm -r $SAM $SM/tmp
    touch $DONE2
fi

if [[ -f $DONE3 ]]; then
    echo "Skip the cram indexing step."
else
    $SAMTOOLS index $CRAM
    touch $DONE3
fi

printf -- "[$(date)] Finish bam2cram: $BAM\n---\n"
