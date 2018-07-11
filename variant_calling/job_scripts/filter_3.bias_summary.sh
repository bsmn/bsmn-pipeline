#!/bin/bash
#$ -cwd
#$ -pe threaded 1

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) [sample name] [ploidy]"
    exit 1
fi

source $(pwd)/run_info

set -eu -o pipefail

SM=$1
PL=$2

VAF=$SM/vaf/$SM.ploidy_$PL.known_germ_filtered.pass.snvs.txt
STR=$SM/strand/$SM.ploidy_$PL.known_germ_filtered.pass.snvs.txt
SUM=$SM/bias_summary/$SM.ploidy_$PL.known_germ_filtered.pass.snvs.txt

printf -- "---\n[$(date)] Start generate bias summary.\n"
mkdir -p $SM/bias_summary

printf "#chr\tpos\tref\talt\tdepth\tref_n\talt_n\t" > $SUM
printf "ref_fwd\tref_rev\talt_fwd\talt_rev\tp_binom\tp_poisson\tp_fisher\t" >> $SUM
printf "som_vs_germ\tstrand_bais1\tstrand_bias2\t" >> $SUM
printf "enough_alt\tstarnds_in_alt\tallelic_locus\tmask\n" >> $SUM

paste $VAF $STR \
    |grep -v ^# \
    |awk -v samtools=$SAMTOOLS -v mask=$MASK1KG '{
cmd=samtools" faidx "mask" "$1":"$2"-"$2"|tail -n1";
cmd|getline mask_base;
close(cmd);
if ($9 < 1e-5) a="som"; else a="germ"; 
if ($18 >= 0.05) b="unbiased"; else b="bias1"; 
if ($27 >= 0.05) c="unbiased"; else c="bias2"; 
if ($8 >= 5) d="enough_alt_reads"; else d="not_enough_alt_reads";
if ($24 >= 1 && $25 >=1) e="both_strands_in_alt_reads"; else e="one_strand_in_alt_reads";
if ($6 > $7 + $8) f="multiallelic_site"; else f="biallelic_site";
print $1"\t"$2"\t"$3"\t"$4"\t"$6"\t"$7"\t"$8"\t"$20"\t"$21"\t"$24"\t"$25"\t"$9"\t"$18"\t"$27"\t"a"\t"b"\t"c"\t"d"\t"e"\t"f"\t"mask_base
}' >> $SUM

printf -- "[$(date)] Finish generate bias summary.\n---\n"
