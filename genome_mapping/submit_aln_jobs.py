#!/usr/bin/env python3

import argparse
import glob
import os
import sys

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/job_scripts"
sys.path.append(pipe_home)

from library.config import log_dir
from library.job_queue import GridEngineQueue

def main():
    args = parse_args()
    q = GridEngineQueue()
    
    jid_list = []
    for pu in [fastq.split(".")[1] for fastq in glob.glob("{sample}/fastq/{sample}.*.R1.fastq.gz".format(sample=args.sample))]:
        jid_list.append(q.submit(opt(args.sample), 
            "{job_home}/aln_1.align_sort.sh {sample} {pu}".format(job_home=job_home, sample=args.sample, pu=pu)))
    jid = ",".join(jid_list)
    
    jid = q.submit(opt(args.sample, jid), 
        "{job_home}/aln_2.merge_bam.sh {sample}".format(job_home=job_home, sample=args.sample))

    jid = q.submit(opt(args.sample, jid),
        "{job_home}/aln_3.markdup.sh {sample}".format(job_home=job_home, sample=args.sample))

    jid = q.submit(opt(args.sample, jid),
        "{job_home}/aln_4.indel_realign.sh {sample}".format(job_home=job_home, sample=args.sample))

    jid = q.submit(opt(args.sample, jid), 
        "{job_home}/aln_5.bqsr.sh {sample}".format(job_home=job_home, sample=args.sample))

    if parentid() != "None":
        q.submit(opt(args.sample, jid), 
            "{job_home}/aln_6.upload_bam.sh {sample}".format(job_home=job_home, sample=args.sample))

def parse_args():
    parser = argparse.ArgumentParser(description='Alignment job submitter')
    parser.add_argument('sample', metavar='sample name')
    return parser.parse_args()

def parentid():
    with open('run_info') as run_info:
        for line in run_info:
            if line[:8] == "PARENTID":
                return line.strip().split("=")[1]

def opt(sample, jid=None):
    opt = "-j y -o {log_dir} -l h_vmem=2G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt
  
if __name__ == "__main__":
    main()
