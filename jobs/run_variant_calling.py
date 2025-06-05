#!/usr/bin/env python3

import argparse
import os
import sys
from collections import defaultdict, deque

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/variant_calling"
sys.path.append(pipe_home)

from library.config import run_info, run_info_append, log_dir
#from library.login import synapse_login, nda_login
from library.parser import sample_list
from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()

    #synapse_login()
    #nda_login()

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
        run_info(f_run_info, args.reference, args.conda_env)
        run_info_append(f_run_info, "\n#RUN_OPTIONS")
        run_info_append(f_run_info, "Q={}".format(args.queue))
        run_info_append(f_run_info, "CONDA_ENV={}".format(args.conda_env))
        run_info_append(f_run_info, "SAMPLE_LIST={}".format(args.sample_list))
        run_info_append(f_run_info, "ALIGNFMT={}".format(args.align_fmt))
        run_info_append(f_run_info, "FILETYPE={}".format(filetype))
        run_info_append(f_run_info, "REFVER={}".format(args.reference))
        run_info_append(f_run_info, "RUN_FILTERS={}".format(args.run_filters))
        run_info_append(f_run_info, "MULTI_ALIGNS={}".format(len(sdata) > 1))
        run_info_append(f_run_info, "UPLOAD={}".format(args.upload))
        run_info_append(f_run_info, "SKIP_CNVNATOR={}".format(args.skip_cnvnator))
        run_info_append(f_run_info, "RUN_MUTECT_SINGLE={}".format(args.run_mutect_single))
        if args.run_gatk_hc:
            ploidy = " ".join(str(i) for i in args.run_gatk_hc)
            run_info_append(f_run_info, "RUN_GATK_HC=True\nPLOIDY=\"{}\"".format(ploidy))
            run_info_append(f_run_info, "MAX_GAUSSIANS={}".format(args.max_gaussians))
        else:
            run_info_append(f_run_info, "RUN_GATK_HC={}".format(args.run_gatk_hc))

        if filetype == "fastq":
            raise Exception("The input filetype should be bam or cram.")

        #global down_jid
        #jid_list = []
        #for fname, loc in sdata:
        #    down_jid = down_jid_queue.popleft()
        #    jid = q.submit(opt(sample, args.queue, down_jid), 
        #            "{job_home}/pre_1.download.sh {sample} {fname} {loc}".format(
        #                job_home=job_home, sample=sample, fname=fname, loc=loc))
        #    jid_list.append(jid)
        #    down_jid_queue.append(jid)
        #jid = ",".join(jid_list)

        if args.align_fmt == "cram" and filetype == "bam":
            raise Exception("alignment format should be set to {}".format(filetype))
            #jid = q.submit(opt(sample, args.queue),
            #    "{job_home}/pre_2.bam2cram.sh {sample}".format(
            #        job_home=job_home, sample=sample))
            #jid = q.submit(opt(sample, args.queue, jid),
            #    "{job_home}/pre_2b.unmapped_reads.sh {sample}".format(
            #        job_home=job_home, sample=sample))

        #jid = q.submit(opt(sample, args.queue, jid),
        jid = q.submit(opt(sample, args.queue),
            "{job_home}/pre_3.run_variant_calling.sh {sample}".format(
                job_home=job_home, sample=sample))
        #if args.upload is not None:
        #    q.submit(opt(sample, args.queue, jid),
        #        "{job_home}/pre_4.upload_cram.sh {sample}".format(
        #            job_home=job_home, sample=sample))

        print()

def opt(sample, Q, jid=None):
    opt = "--partition={q} --output {log_dir}/%x.%j.stdout --error {log_dir}/%x.%j.stderr --parsable".format(q=Q, log_dir=log_dir(sample))
    if jid is not None:
        opt = "-d afterok:{jid} {opt}".format(jid=jid, opt=opt)
    return opt

def parse_args():
    parser = argparse.ArgumentParser(description='Variant Calling Pipeline')
    parser.add_argument('--con-down-limit', metavar='int', type=int,
        help='''The maximum allowded number of concurrent downloads
        [ Default: 6 ]''', default=6)
    parser.add_argument('--upload', metavar='syn123', 
        help='''Synapse ID of project or folder where to upload result cram files. 
        If it is not set, the result cram files will be locally saved.
        [ Default: None ]''', default=None)
    parser.add_argument('-q', '--queue', metavar='queue', required=True,
        help='''Specify the queue name of Sun Grid Engine for jobs to be submitted''')
    parser.add_argument('-n', '--conda-env', metavar='env',
        help='''Specify the name of conda environment for pipeline [default is bp]''', default="bp")
    parser.add_argument('-p', '--run-gatk-hc', metavar='ploidy', type=int, nargs='+', default=False)
    parser.add_argument('--max-gaussians', metavar='int', type=int,
        help='''Set the maximum number of Gaussians for gatk VQSR step''', default=4)
    parser.add_argument('--run-mutect-single', action='store_true')
    parser.add_argument('--skip-cnvnator', action='store_true', default=False)
    parser.add_argument('--run-filters', action='store_true', default=False)
    parser.add_argument('-f', '--align-fmt', metavar='fmt',
        help='''Alignment format [cram (default) or bam]''', default="cram")
    parser.add_argument('-r', '--reference', metavar='ref',
        help='''Reference version [b37 (default) or hg19]''', default="b37")
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
