#!/usr/bin/env python3

import argparse
import os
import sys
from collections import defaultdict

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/genome_mapping"
sys.path.append(pipe_home)

from library.config import run_info, run_info_append, log_dir
from library.login import synapse_login, nda_login
from library.parser import sample_list
from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()

    synapse_login()
    nda_login()

    samples = sample_list(args.sample_list)
    for key, val in samples.items():
        sample, filetype = key
        print("- Sample: " + sample)

        f_run_jid = sample + "/run_jid"
        if q.num_run_jid_in_queue(f_run_jid) > 0:
            print("There are submitted jobs for this sample.")
            print("Skip to submit jobs.\n")
            continue
        q.set_run_jid(f_run_jid, new=True)

        f_run_info = sample + "/run_info"
        run_info(f_run_info)
        run_info_append(f_run_info, "\n#RUN_OPTIONS")
        run_info_append(f_run_info, "UPLOAD={}".format(args.upload))
        run_info_append(f_run_info, "RUN_CNVNATOR={}".format(args.run_cnvnator))
        run_info_append(f_run_info, "RUN_MUTECT_SINGLE={}".format(args.run_mutect_single))
        if args.run_gatk_hc:
            ploidy = " ".join(str(i) for i in args.run_gatk_hc)
            run_info_append(f_run_info, "RUN_GATK_HC=True\nPLOIDY=\"{}\"".format(ploidy))
        else:
            run_info_append(f_run_info, "RUN_GATK_HC={}".format(args.run_gatk_hc))

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
    opt = "-j y -o {log_dir} -l h_vmem=4G".format(log_dir=log_dir(sample))
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
        "{job_home}/pre_3.submit_aln_jobs.sh {sample}".format(
            job_home=job_home, sample=sample))

def parse_args():
    parser = argparse.ArgumentParser(description='Genome Mapping Pipeline')
    parser.add_argument('--upload', metavar='syn123', 
        help='''Synapse ID of project or folder where to upload result cram files. 
        If it is not set, the result cram files will be locally saved.
        [ Default: None ]''', default=None)
    parser.add_argument('--run-gatk-hc', metavar='ploidy', type=int, nargs='+', default=False)
    parser.add_argument('--run-mutect-single', action='store_true')
    parser.add_argument('--run-cnvnator', action='store_true')
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
