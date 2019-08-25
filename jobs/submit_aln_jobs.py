#!/usr/bin/env python3

import argparse
import glob
import os
import sys

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/genome_mapping"
sys.path.append(pipe_home)

from library.config import log_dir, save_hold_jid
from library.job_queue import GridEngineQueue

def main():
    args = parse_args()
    q = GridEngineQueue()

    jid_list = []
    for pu in [fastq.split(".")[1] for fastq in glob.glob("{sample}/fastq/{sample}.*.R1.fastq.gz".format(sample=args.sample_name))]:
        jid_list.append(q.submit(opt(args.sample_name), 
            "{job_home}/aln_1.align_sort.sh {sample} {pu}".format(job_home=job_home, sample=args.sample_name, pu=pu)))
    jid = ",".join(jid_list)
    
    jid = q.submit(opt(args.sample_name, jid), 
        "{job_home}/aln_2.merge_bam.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    jid = q.submit(opt(args.sample_name, jid),
        "{job_home}/aln_3.markdup.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    jid = q.submit(opt(args.sample_name, jid),
        "{job_home}/aln_4.indel_realign.sh {sample}".format(job_home=job_home, sample=args.sample_name))
    jid = q.submit(opt(args.sample_name, jid), 
        "{job_home}/aln_5.bqsr.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    jid = q.submit(opt(args.sample_name, jid), 
        "{job_home}/post_1.unmapped_reads.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    save_hold_jid("{sample}/alignment/hold_jid".format(sample=args.sample_name), jid)

    jid = q.submit(opt(args.sample_name), 
        "{job_home}/post_2.run_variant_calling.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    q.submit(opt(args.sample_name, jid), 
        "{job_home}/post_3.upload_cram.sh {sample}".format(job_home=job_home, sample=args.sample_name))

def parse_args():
    parser = argparse.ArgumentParser(description='Alignment job submitter')
    parser.add_argument('--sample-name', metavar='sample name', required=True)
    return parser.parse_args()

def opt(sample, jid=None):
    opt = "-j y -o {log_dir} -l h_vmem=4G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

if __name__ == "__main__":
    main()
