#!/usr/bin/env python3

import argparse
import os
import sys
from collections import defaultdict

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/variant_calling"
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

    samples = sample_list2(args.sample_list)
    for sample, sdata in samples.items():
        print(sample)

        run_info(sample + "/run_info")

        jid_pre = submit_pre_jobs(sample, sdata)
        jid_list = []
        for ploidy in range(2,11):
            jid = submit_gatk_jobs(sample, ploidy, jid_pre)
            jid = submit_filter_jobs(sample, ploidy, jid)
            jid_list.append(jid)
        jid = ",".join(jid_list)
        submit_post_jobs(sample, jid)
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
        "{job_home}/pre_2.cnvnator.sh {sample}".format(
            job_home=job_home, sample=sample))
    return jid

def submit_gatk_jobs(sample, ploidy, jid):
    jid = q.submit(
        "-t 1-24 {opt}".format(opt=opt(sample, jid)),
        "{job_home}/gatk_1.hc_gvcf.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(
        "-t 1-24 {opt}".format(opt=opt(sample, jid)),
        "{job_home}/gatk_2.joint_gt.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid),
        "{job_home}/gatk_3.concat_vcf.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid),
        "{job_home}/gatk_4.vqsr.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    return jid

def submit_filter_jobs(sample, ploidy, jid):
    jid = q.submit(opt(sample, jid),
        "{job_home}/filter_1.known_germ_filtering.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid_vaf = q.submit(opt(sample, jid),
        "{job_home}/filter_2-1.vaf_info.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid_str = q.submit(opt(sample, jid),
        "{job_home}/filter_2-2.strand_info.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid_vaf+","+jid_str),
        "{job_home}/filter_3.bias_summary.sh {sample} {ploidy}".format(
            job_home=job_home, sample=sample, ploidy=ploidy))
    return jid

def submit_post_jobs(sample, jid):
    jid = q.submit(opt(sample, jid),
        "{job_home}/post_1.candidates.sh {sample}".format(
            job_home=job_home, sample=sample))
    return jid

def parse_args():
    parser = argparse.ArgumentParser(description='Variant Calling Pipeline')
    parser.add_argument('--sample-list', metavar='sample_list.txt', required=True,
        help='''Sample list file.
        Each line format is "sample_id\\tfile_name\\tlocation".
        Lines staring with "#" will omitted.
        Header line should also start with "#".
        Trailing columns will be ignored.
        "location" is Synapse ID, S3Uri of the NDA or a user, or LocalPath.
        For data download, synapse or aws clients, or symbolic link will be used, respectively.''')
    return parser.parse_args()

if __name__ == "__main__":
    main()
