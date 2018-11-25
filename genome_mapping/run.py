#!/usr/bin/env python3

import argparse
import configparser
import pandas as pd
import synapseclient
import subprocess
import pathlib
import os
import sys
from collections import defaultdict

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
util_home = pipe_home + "/analysis_utils"
job_home = cmd_home + "/job_scripts"
sys.path.append(pipe_home)

from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()
    samples = parse_sample_file(args.infile)
    synapse_login()
    save_run_info(args.parentid)
    
    for key, val in samples.items():
        sample, filetype = key
        print(sample)
        if filetype == "bam":
            fname, synid = val[0]
            jid = submit_pre_jobs_bam(sample, fname, synid)
        else:
            jid_list = []
            for sdata in val:
                fname, synid = sdata
                jid_list.append(submit_pre_jobs_fastq(sample, fname, synid))
            jid = ",".join(jid_list)
        submit_aln_jobs(sample, jid)
        print()

def opt(sample, jid=None):
    opt = "-j y -o {log_dir} -l h_vmem=2G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def submit_pre_jobs_fastq(sample, fname, synid):
    jid = q.submit(opt(sample), 
        "{job_home}/pre_1.download.sh {sample} {fname} {synid}".format(
            job_home=job_home, sample=sample, fname=fname, synid=synid))
    
    jid = q.submit(opt(sample, jid),
        "{job_home}/pre_2.split_fastq_by_RG.sh {sample}/downloads/{fname}".format(
            job_home=job_home, sample=sample, fname=fname))

    return jid

def submit_pre_jobs_bam(sample, fname, synid):
    jid = q.submit(opt(sample), 
        "{job_home}/pre_1.download.sh {sample} {fname} {synid}".format(
            job_home=job_home, sample=sample, fname=fname, synid=synid))

    jid = q.submit(opt(sample, jid), 
        "{job_home}/pre_1b.bam2fastq.sh {sample} {fname}".format(
            job_home=job_home, sample=sample, fname=fname))
        
    jid_list = []
    for read in ["R1", "R2"]:
        fastq = "{sample}/fastq/{sample}.{read}.fastq.gz".format(sample=sample, read=read)
        jid_list.append(q.submit(opt(sample, jid),
            "{job_home}/pre_2.split_fastq_by_RG.sh {sample}/fastq/{sample}.{read}.fastq.gz".format(
                job_home=job_home, sample=sample, read=read)))
    jid = ",".join(jid_list)

    return jid

def submit_aln_jobs(sample, jid):
    q.submit(opt(sample, jid),
        "{job_home}/pre_3.submit_aln_jobs.sh {host} {sample}".format(
            job_home=job_home, host=os.getenv("HOSTNAME"), sample=sample))

def parse_args():
    parser = argparse.ArgumentParser(description='Genome Mapping Pipeline')
    parser.add_argument('infile', metavar='sample_list.txt', 
        help='Sample list file shoud have sample_id, synapse_id, and file_name.')
    parser.add_argument('--parentid', metavar='syn123', 
        help='''Synapse ID of project or folder where to upload result bam files. 
If it is not set, the result bam files will be locally saved.
Default: None''', default=None)

    return parser.parse_args()

def filetype(fname):
    return "bam" if os.path.splitext(fname)[1] == ".bam" else "fastq"

def parse_sample_file(sfile):
    samples = defaultdict(list)
    for sname, group in pd.read_table(sfile).groupby("sample_id"):
        for idx, sdata in group.iterrows():
            key = (sname, filetype(sdata["file"]))
            val = (sdata["file"], sdata["synapse_id"])
            samples[key].append(val)
    return samples
    
def synapse_login():
    try:
        synapseclient.login()
    except:
        subprocess.run(['synapse', 'login', '--remember-me'])

def save_run_info(parentid):
    config = configparser.ConfigParser()
    config.read(pipe_home + "/config.ini")

    with open("run_info", "w") as run_file:
        run_file.write("CMD_HOME={path}\n".format(path=cmd_home))
        run_file.write("UTIL_HOME={path}\n".format(path=util_home))

        for section in config.sections():
            run_file.write("\n#{section}\n".format(section=section))
            for key in config[section]:
                run_file.write("{key}={path}/{val}\n".format(
                    key=key.upper(), val=config[section][key], path=pipe_home))

        run_file.write("\n#SYNAPSE\n")
        run_file.write("PARENTID={id}\n".format(id=parentid))

def log_dir(sample):
    log_dir = sample+"/logs"
    pathlib.Path(log_dir).mkdir(parents=True, exist_ok=True)
    return log_dir

if __name__ == "__main__":
    main()
