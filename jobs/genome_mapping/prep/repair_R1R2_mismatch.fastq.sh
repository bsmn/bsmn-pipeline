#!/bin/bash
#$ -cwd
#$ -pe threaded 4
#$ -o q.log
#$ -j y
#$ -l h_vmem=11G
#$ -V

trap "exit 100" ERR

# submit the script like below:
# for F in *.R1.fastq.gz; do qsub -q 1-day /path/to/this.sh $F; done

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) [R1 or R2 FQSTQ file]"
    false
fi

R1=${1/.R[12]./.R1.}
R1FIX=${R1/.R1./.R1.fixed.}
R1OLD=${R1FIX/fixed/old}
R2=${1/.R[12]./.R2.}
R2FIX=${R2/.R2./.R2.fixed.}
R2OLD=${R2FIX/fixed/old}

printf -- "---\n[$(date)] Start fixing paired-end fastq files: $(basename $R1) $(basename $R2)\n"

/home/mayo/m216456/opt/bbmap/repair.sh -Xmx32G \
    in1=$R1 in2=$R2 \
    out1=$R1FIX out2=$R2FIX \
    outsingle=${R1/.R1.*/.single.fq} \
    qout=33 \
    repair
mv $R1 $R1OLD; mv $R2 $R2OLD
mv $R1FIX $R1; mv $R2FIX $R2

printf -- "---\n[$(date)] Finished fixing fastq files.\n"
