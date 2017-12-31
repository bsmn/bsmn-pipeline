#!/usr/bin/env python3

import argparse
import pathlib
import glob
import os
import sys
from library.job_queue import GridEngineQueue

pipe_home = os.path.dirname(os.path.realpath(__file__))

def main():
    args = parse_args()
    q = GridEngineQueue()
    
    jid_list = []
    for pu in [fastq.split(".")[1] for fastq in glob.glob("{sample}/fastq/{sample}.*.R1.fastq.gz".format(sample=args.sample))]:
        jid_list.append(q.submit(opt(args.sample), 
            "{pipe_home}/job_scripts/aln_1.align_sort.sh {sample} {pu}".format(pipe_home=pipe_home, sample=args.sample, pu=pu)))
    jid = ",".join(jid_list)
    
    jid = q.submit(opt(args.sample, jid), 
        "{pipe_home}/job_scripts/aln_2.merge_bam.sh {sample}".format(pipe_home=pipe_home, sample=args.sample))

    jid = q.submit(opt(args.sample, jid),
        "{pipe_home}/job_scripts/aln_3.markdup.sh {sample}".format(pipe_home=pipe_home, sample=args.sample))

    jid = q.submit(opt(args.sample, jid),
        "{pipe_home}/job_scripts/aln_4.indel_realign.sh {sample}".format(pipe_home=pipe_home, sample=args.sample))

    jid = q.submit(opt(args.sample, jid), 
        "{pipe_home}/job_scripts/aln_5.bqsr.sh {sample}".format(pipe_home=pipe_home, sample=args.sample))

    q.submit(opt(args.sample, jid), 
        "{pipe_home}/job_scripts/aln_6.upload_bam.sh {sample}".format(pipe_home=pipe_home, sample=args.sample))

def parse_args():
    parser = argparse.ArgumentParser(description='Alignment job submitter')
    parser.add_argument('sample', metavar='sample name')
    return parser.parse_args()

def log_dir(sample):
    log_dir = sample+"/logs"
    pathlib.Path(log_dir).mkdir(parents=True, exist_ok=True)
    return log_dir

def opt(sample, jid=None):
    opt = "-j y -o {log_dir} -l h_vmem=2G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt
  
if __name__ == "__main__":
    main()
