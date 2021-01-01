#!/usr/bin/env python3

import argparse
import glob
import os
import sys

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/variant_calling"
sys.path.append(pipe_home)

from library.config import log_dir, save_hold_jid
from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()
    q.set_run_jid(args.sample_name + "/run_jid")

    jid_list = []
    for ploidy in args.ploidy:
        jid_list.append(submit_jobs(args.sample_name, args.queue, ploidy, args.hold_jid, args.multiple_alignments))
    jid = ",".join(jid_list)
    jid = q.submit(opt(args.sample_name, args.queue, jid),
        "{job_home}/start_variant_filtering.sh {sample}".format(
            job_home = cmd_home + "/variant_filtering/prep", sample=args.sample_name))
    save_hold_jid("{sample}/gatk-hc/hold_jid".format(sample=args.sample_name), jid)
    
def parse_args():
    parser = argparse.ArgumentParser(description='GATK-HC job submitter')
    parser.add_argument('--queue', metavar='SGE queue', required=True)
    parser.add_argument('--ploidy', metavar='int', nargs='+', type=int, default=2)
    parser.add_argument('--multiple-alignments', action='store_true', default=False)
    parser.add_argument('--hold_jid', default=None)
    parser.add_argument('--sample-name', metavar='sample name', required=True)
    return parser.parse_args()

def opt(sample, Q, jid=None):
    opt = "-V -q {q} -r y -j y -o {log_dir} -l h_vmem=11G".format(q=Q, log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def submit_jobs(sample, Q, ploidy, jid, malign):
    if malign:
        jid = q.submit(
            "-t 1-24 -pe threaded 10 {opt}".format(opt=opt(sample, Q, jid)),
            "{job_home}/gatk-hc_1.call.sh {sample} {ploidy} 92G".format(
                job_home=job_home, sample=sample, ploidy=ploidy))
    else:
        jid = q.submit(
            "-t 1-24 {opt}".format(opt=opt(sample, Q, jid)),
            "{job_home}/gatk-hc_1.call.sh {sample} {ploidy}".format(
                job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, Q, jid),
        "{job_home}/gatk-hc_2.concat_vcf.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, Q, jid),
        "{job_home}/gatk-hc_3.vqsr.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    return jid

if __name__ == "__main__":
    main()
