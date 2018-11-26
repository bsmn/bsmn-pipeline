#!/usr/bin/env python3

import argparse
import pathlib
import os
import sys
from collections import defaultdict

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/job_scripts"
sys.path.append(pipe_home)

from library.config import run_info, run_info_append
from library.login import synapse_login, nda_login
from library.parser import sample_list
from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()

    synapse_login()
    nda_login()

    run_info()
    run_info_append("\n#SYNAPSE\nPARENTID={}".format(args.parentid))

    samples = sample_list(args.infile)
    for key, val in samples.items():
        sample, filetype = key
        print(sample)
        jid_list = []
        for sdata in val:
            fname, loc = sdata
            if filetype == "bam":
                jid_list.append(submit_pre_jobs_bam(sample, fname, loc))
            else:
                jid_list.append(submit_pre_jobs_fastq(sample, fname, loc))
            jid = ",".join(jid_list)
        submit_aln_jobs(sample, jid)
        print()

def opt(sample, jid=None):
    opt = "-j y -o {log_dir} -l h_vmem=2G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def submit_pre_jobs_fastq(sample, fname, loc):
    jid = q.submit(opt(sample), 
        "{job_home}/pre_1.download.sh {sample} {fname} {loc}".format(
            job_home=job_home, sample=sample, fname=fname, loc=loc))
    
    jid = q.submit(opt(sample, jid),
        "{job_home}/pre_2.split_fastq_by_RG.sh {sample}/downloads/{fname}".format(
            job_home=job_home, sample=sample, fname=fname))

    return jid

def submit_pre_jobs_bam(sample, fname, loc):
    jid = q.submit(opt(sample), 
        "{job_home}/pre_1.download.sh {sample} {fname} {loc}".format(
            job_home=job_home, sample=sample, fname=fname, loc=loc))

    jid = q.submit(opt(sample, jid), 
        "{job_home}/pre_1b.bam2fastq.sh {sample} {fname}".format(
            job_home=job_home, sample=sample, fname=fname))
        
    jid_list = []
    for read in ["R1", "R2"]:
        jid_list.append(q.submit(opt(sample, jid),
            "{job_home}/pre_2.split_fastq_by_RG.sh {sample}/fastq/{fname}.{read}.fastq.gz".format(
                job_home=job_home, sample=sample, fname=fname, read=read)))
    jid = ",".join(jid_list)

    return jid

def submit_aln_jobs(sample, jid):
    q.submit(opt(sample, jid),
        "{job_home}/pre_3.submit_aln_jobs.sh {host} {sample}".format(
            job_home=job_home, host=os.getenv("HOSTNAME"), sample=sample))

def parse_args():
    parser = argparse.ArgumentParser(description='Genome Mapping Pipeline')
    parser.add_argument('infile', metavar='sample_list.txt', 
        help='''Sample list file. 
        Each line format is "sample_id\\tfile_name\\tlocation".
        Header line should start with "#". Trailing columns will be ignored.
        "location" is either a synapse_id, or a s3_location of the NDA. 
        For data download, synapse or aws clients will be used, respectively.''')
    parser.add_argument('--parentid', metavar='syn123', 
        help='''Synapse ID of project or folder where to upload result bam files. 
        If it is not set, the result bam files will be locally saved.
        [ Default: None ]''', default=None)
    return parser.parse_args()

def log_dir(sample):
    log_dir = sample+"/logs"
    pathlib.Path(log_dir).mkdir(parents=True, exist_ok=True)
    return log_dir

if __name__ == "__main__":
    main()
