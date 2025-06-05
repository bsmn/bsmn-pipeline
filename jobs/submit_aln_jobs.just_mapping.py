#!/usr/bin/env python3

import argparse
import glob
import os
import sys
import re

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/genome_mapping"
sys.path.append(pipe_home)

from library.config import log_dir, save_hold_jid
from library.job_queue import GridEngineQueue

def main():
    args = parse_args()
    q = GridEngineQueue()
    q.set_run_jid(args.sample_name + "/run_jid")

    jid_list = []

    #fastq_path = "{sample}/fastq/{sample}.*.R1.fastq.gz".format(sample=args.sample_name)
    #done_path = "{sample}/run_status/aln_1.align_sort.*.done".format(sample=args.sample_name)
    #pu_list = set([fastq.replace(".R1.fastq.gz","").split(".")[-1] for fastq in glob.glob(fastq_path)] +
    #              [done.split(".")[-2] for done in glob.glob(done_path)])
    pu_list = set([re.match(rf"{re.escape(args.sample_name)}\.(.+).R1.fastq.gz", fastq.split("/")[-1]).group(1)
                   for fastq in glob.glob("{sample}/fastq/{sample}.*.R1.fastq.gz".format(sample=args.sample_name))])
    for pu in pu_list: 
        jid_list.append(q.submit(opt(args.sample_name, args.queue), 
            "{job_home}/aln_1.align_sort.sh {sample} {pu}".format(job_home=job_home, sample=args.sample_name, pu=pu)))
    if jid_list:
        jid = ",".join(jid_list)
    else:
        jid = None
    
    jid = q.submit(opt(args.sample_name, args.queue, jid), 
        "{job_home}/aln_2.merge_bam.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    #if not args.target_seq:
    #    jid = q.submit(opt(args.sample_name, args.queue, jid),
    #        "{job_home}/aln_3.markdup.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    #    jid = q.submit(opt(args.sample_name, args.queue, jid),
    #        "{job_home}/aln_4.indel_realign.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    #    jid = q.submit(opt(args.sample_name, args.queue, jid), 
    #        "{job_home}/aln_5.bqsr.sh {sample}".format(job_home=job_home, sample=args.sample_name))
    #aln_jid = jid

    #jid = q.submit(opt(args.sample_name, args.queue, aln_jid), 
    #    "{job_home}/post_1.unmapped_reads.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    #save_hold_jid("{sample}/alignment/hold_jid".format(sample=args.sample_name), jid)

    #jid = q.submit(opt(args.sample_name, args.queue, aln_jid), 
    #    "{job_home}/post_2.run_variant_calling.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    #q.submit(opt(args.sample_name, args.queue, jid), 
    #    "{job_home}/post_3.upload_cram.sh {sample}".format(job_home=job_home, sample=args.sample_name))

def parse_args():
    parser = argparse.ArgumentParser(description='Alignment job submitter')
    parser.add_argument('--queue', metavar='SGE queue', required=True)
    parser.add_argument('-t', '--target-seq', action='store_true', default=False)
    parser.add_argument('--sample-name', metavar='sample name', required=True)
    return parser.parse_args()

def opt(sample, Q, jid=None):
    opt = "--partition={q} --output {log_dir}/%x.%j.stdout --error {log_dir}/%x.%j.stderr --parsable".format(q=Q, log_dir=log_dir(sample))
    if jid is not None:
        opt = "-d afterok:{jid} {opt}".format(jid=jid, opt=opt)
    return opt

if __name__ == "__main__":
    main()
