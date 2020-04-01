#!/usr/bin/env python3

import argparse
import os
import re
import sys
from collections import deque

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

    global down_jid_queue
    down_jid_queue = deque([None] * args.con_down_limit)

    samples = sample_list(args.sample_list)
    for (sample, filetype), sdata in samples.items():
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

        if filetype == "bam":
            jid = submit_pre_jobs_bam(sample, sdata)
        else:
            jid = submit_pre_jobs_fastq(sample, sdata)

        submit_aln_jobs(sample, jid)
        print()

def opt(sample, jid=None):
    opt = "-r y -j y -o {log_dir} -l h_vmem=4G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def submit_pre_jobs_fastq(sample, sdata):
    global down_jid_queue

    jid_per_read = {"R1":[], "R2":[]}
    fq_per_read = {"R1":[], "R2":[]}
    for fname, loc in sdata:
        read = "R1" if re.search("(.R1|_R1|_r1|_1)(|_001).f(|ast)q(|.gz)", fname) else "R2"

        down_jid = down_jid_queue.popleft()
        cmd = "{job_home}/pre_1.download.sh {sample} {fname} {loc}".format(job_home=job_home, sample=sample, fname=fname, loc=loc)
        q_opt_str = opt(sample, down_jid)
        jid = q.submit(q_opt_str, cmd)

        down_jid_queue.append(jid)

        jid_per_read[read].append(jid)
        fq_per_read[read].append("{}/downloads/{}".format(sample, fname))

    jid_list = []
    for read in ["R1", "R2"]:
        fq_files = " ".join(sorted(fq_per_read[read]))
        jid = ",".join(jid_per_read[read])
        jid_list.append(q.submit(opt(sample, jid),
            "{job_home}/pre_2.split_fastq_by_RG.sh {fq_files}".format(
                job_home=job_home, fq_files=fq_files)))
    jid = ",".join(jid_list)

    return jid

def submit_pre_jobs_bam(sample, sdata):
    fname, loc = sdata[0]

    global down_jid_queue
    down_jid = down_jid_queue.popleft()

    cmd = "{job_home}/pre_1.download.sh {sample} {fname} {loc}".format(job_home=job_home, sample=sample, fname=fname, loc=loc)
    q_opt_str = opt(sample, down_jid)
    jid = q.submit(q_opt_str, cmd)

    down_jid_queue.append(jid)

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
    parser.add_argument('--con-down-limit', metavar='int', type=int,
        help='''The maximum allowded number of concurrent downloads
        [ Default: 6 ]''', default=6)
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
