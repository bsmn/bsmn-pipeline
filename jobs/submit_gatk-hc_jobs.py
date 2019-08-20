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
    print(args)
    jid_list = []
    for ploidy in args.ploidy:
        jid_list.append(submit_jobs(args.sample_name, ploidy, args.hold_jid))
    jid = ",".join(jid_list)
    save_hold_jid("{sample}/gatk-hc/hold_jid".format(sample=args.sample_name), jid)
    
def parse_args():
    parser = argparse.ArgumentParser(description='GATK-HC job submitter')
    parser.add_argument('--ploidy', metavar='int', nargs='+', type=int, default=2)
    parser.add_argument('--hold_jid', default=None)
    parser.add_argument('--sample-name', metavar='sample name', required=True)
    return parser.parse_args()

def opt(sample, jid=None):
    opt = "-j y -o {log_dir} -l h_vmem=4G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def submit_jobs(sample, ploidy, jid):
    jid = q.submit(
        "-t 1-24 {opt}".format(opt=opt(sample, jid)),
        "{job_home}/gatk-hc_1.call.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(
        "-t 1-24 {opt}".format(opt=opt(sample, jid)),
        "{job_home}/gatk-hc_2.concat_vcf.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid),
        "{job_home}/gatk-hc_3.vqsr.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    return jid

if __name__ == "__main__":
    main()
