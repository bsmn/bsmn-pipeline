#!/usr/bin/env python3

import argparse
import os
import sys
from collections import defaultdict

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/job_scripts"
sys.path.append(pipe_home)

from library.config import run_info, log_dir
from library.login import synapse_login, nda_login
from library.parser import sample_list2
from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()

    synapse_login()
    nda_login()

    samples = sample_list2(args.infile)
    for sample, sdata in samples.items():
        print(sample)

        run_info(sample + "/run_info")

        jid_pre = submit_pre_jobs(sample, sdata)
        submit_main_jobs(sample, jid_pre)
        print()

def opt(sample, jid=None):
    opt = "-r y -j y -o {log_dir} -l h_vmem=4G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def submit_pre_jobs(sample, sdata):
    jid_list = []
    for fname, loc in sdata:
        jid_list.append(
            q.submit(opt(sample), 
                "{job_home}/pre_1.download.sh {sample} {fname} {loc}".format(
                    job_home=job_home, sample=sample, fname=fname, loc=loc)))
    jid = ",".join(jid_list)
    q.submit(opt(sample, jid),
        "{job_home}/pre_2b.unmapped_reads.sh {sample}".format(
            job_home=job_home, sample=sample))
    jid = q.submit(opt(sample, jid),
        "{job_home}/pre_2.bam2cram.sh {sample}".format(
            job_home=job_home, sample=sample))
    return jid

def submit_main_jobs(sample, jid):
    jid = q.submit(
        "-t 1-24 {opt}".format(opt=opt(sample, jid)),
        "{job_home}/mutect-single_1.call.sh {sample}".format(
            job_home=job_home, sample=sample))
    jid = q.submit(opt(sample, jid),
        "{job_home}/mutect-single_2.concat_vcf.sh {sample}".format(
            job_home=job_home, sample=sample))
    return jid

def parse_args():
    parser = argparse.ArgumentParser(description='Variant Calling Pipeline')
    parser.add_argument('infile', metavar='sample_list.txt',
        help='''Sample list file.
        Each line format is "sample_id\\tfile_name\\tlocation".
        Lines staring with "#" will omitted.
        Header line should also start with "#".
        Trailing columns will be ignored.
        "location" is one of Synapse ID, S3Uri, and LocalPath.
        For data download, synapse client, aws client, or symbolic link will be used, respectively.''')
    return parser.parse_args()

if __name__ == "__main__":
    main()
