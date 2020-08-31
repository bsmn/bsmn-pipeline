#!/bin/bash
#$ -cwd
#$ -pe threaded 32
#$ -j y
#$ -o logs
#$ -l h_vmem=1G
#$ -V

pileup() {
    local REF=$1
    shift 1
    local BAMFILES=$*
    cut -f1,2 |\
    while read CHR POS; do
        local R=$CHR:$POS-$POS
        samtools mpileup -r $R -q 20 -Q 20 -B -f $REF $BAMFILES
    done
}
export -f pileup

trap "exit 100" ERR

usage="usage: $(basename $0) -i <indels.txt> -o <out dir> [-r <b37 (default), hg19 or hg38>] [-n <target name>] <BAM file> [<BAM file> ...]"

while getopts i:o:r:n: opt; do
    case $opt in
        i) INDELS=$OPTARG;;
        o) OUTDIR=$OPTARG;;
        r) RVER=$OPTARG;;
        n) TNAME=$OPTARG;;
    ?) echo $usage; exit 1
    esac
done

shift $(($OPTIND-1))

if [ -z $INDELS ] || [ -z $OUTDIR ] || [ $# -lt 1 ]; then
    echo $usage; exit 1
fi
if [ -z $RVER ]; then RVER="b37"; fi

BAMFILES=$*;

if [ -z $NSLOTS ]; then NSLOTS=$(nproc); fi

mkdir -p $OUTDIR
FNAME=$(basename $INDELS)
if [ -z $TNAME ]; then
    FNAME=${FNAME%.*}.$(basename $1)
    FNAME=${FNAME/.bam/}; FNAME=${FNAME/.cram/}
else
    FNAME=${FNAME%.*}.$TNAME
fi
OUTFILE=$OUTDIR/$FNAME.somatic.vaf

if [ $RVER = "hg19" ]; then
    REF=/research/bsi/projects/PI/tertiary/Abyzov_Alexej_m124423/common/ref_genome/hg19/ucsc.hg19.fasta
elif [ $RVER = "b37" ]; then
    REF=/research/bsi/projects/PI/tertiary/Abyzov_Alexej_m124423/common/ref_genome/hg19/human_g1k_v37_decoy.fasta
elif [ $RVER = "hg38" ]; then
    REF=/research/bsi/projects/PI/tertiary/Abyzov_Alexej_m124423/common/ref_genome/hg38/GRCh38_full_analysis_set_plus_decoy_hla.fa
else
    echo "[ERROR] Unknown reference version: $RVER"
    echo $usage; exit 1
fi

NPROC=$((NSLOTS-2))
NLINE=$(($(grep -v ^# $INDELS | wc -l)/$(($NPROC-1))))

printf -- "[$(date)] Smatools mpileup for calculating VAF for indels.\n---\n"
SECONDS=0

echo "[INFO] INPUT: $INDELS"
echo "[INFO] BAM(s): $BAMFILES"
echo "[INFO] OUTPUT: $OUTFILE"
echo "[INFO] $NPROC processors; $NLINE lines per one processor"

TEMPIN=/tmp/$(uuidgen)

grep -v ^# $INDELS \
|if [ $RVER = "b37" ]; then sed 's/^chr//'; else sed '/^chr/! s/^/chr/'; fi \
>$TEMPIN

cat $TEMPIN \
|parallel --pipe -N $NLINE -j $NPROC pileup $REF $BAMFILES \
|awk -v OFS='\t' \
     '{ depth = 0; reads = ""
        for (i = 5; i < NF; i = i + 3) {
            reads = reads toupper(gensub(/\^[+-]/, "", "g", $i))
            depth += $(i-1)
        }
        if (reads !~ /([+-][1-9][0-9]*[ATGC]+)/)
            print $1, $2, toupper($3), "NA", depth
        else
            while (match(reads, /([+-][1-9][0-9]*[ATGC]+)/)) {
                if (substr(reads, RSTART, 1) == "-")
                    print $1, $2, toupper($3) gensub(/[+-][1-9][0-9]*/, "", "g", substr(reads, RSTART, RLENGTH)), toupper($3), depth
                else if (substr(reads,RSTART, 1) == "+")
                    print $1, $2, toupper($3), toupper($3) gensub(/[+-][1-9][0-9]*/, "", "g", substr(reads, RSTART, RLENGTH)), depth
                reads = substr(reads, RSTART + RLENGTH)
            }
     } END { if (NR == 0) print "NA", "NA", "NA", "NA", "NA" }' \
|sort |uniq -c \
|awk -v OFS='\t' \
     'NR==FNR {
         depth[$2, $3] = $6
         if ($5 != "NA") cnt[$2, $3, $4, $5] = $1
         next
      } {
         $5 = depth[$1, $2]
         if ($5 == "") $5 = 0
         $6 = cnt[$1, $2, $3, $4]
         if ($6 == "") $6 = 0
         print $1, $2, $3, $4, $5, $6, ($5 != 0) ? $6/$5 : 0
      }' - $TEMPIN \
|cut -f2- \
|paste <(grep -v ^# $INDELS |cut -f1) - \
|sed '1i#CHR\tPOS\tREF\tALT\tDP\tAD\tAF' \
>$OUTFILE

rm $TEMPIN

printf -- "---\n[$(date)] Done.\n"

elapsed=$SECONDS
printf -- "\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

