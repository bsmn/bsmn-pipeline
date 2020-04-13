#!/usr/bin/env python3

import argparse
import glob
import os
import sys

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

    fastq_path = "{sample}/fastq/{sample}.*.R1.fastq.gz".format(sample=args.sample_name)
    done_path = "{sample}/run_status/aln_1.align_sort.*.done".format(sample=args.sample_name)
    pu_list = set([fastq.replace(".R1.fastq.gz","").split(".")[-1] for fastq in glob.glob(fastq_path)] +
                  [done.split(".")[-2] for done in glob.glob(done_path)])
    for pu in pu_list: 
        q_opt = opt(args.sample_name)
        cmd = "{job_home}/aln_1.align_sort.sh {sample} {pu}".format(job_home=job_home, sample=args.sample_name, pu=pu)
        print('aln_1.align_sort.sh\nq_opt:', q_opt, 'cmd:', cmd)
        jid_list.append(q.submit(q_opt, cmd)) 
        #jid_list.append(q.submit(opt(args.sample_name), 
        #    "{job_home}/aln_1.align_sort.sh {sample} {pu}".format(job_home=job_home, sample=args.sample_name, pu=pu)))
    jid = ",".join(jid_list)
    
    q_opt = opt(args.sample_name, jid)
    cmd = "{job_home}/aln_2.merge_bam.sh {sample}".format(job_home=job_home, sample=args.sample_name)
    print('aln_2.merge_bam.sh\nq_opt:', q_opt, 'cmd:', cmd)
    jid = q.submit(q_opt, cmd) 
    #jid = q.submit(opt(args.sample_name, jid), 
    #    "{job_home}/aln_2.merge_bam.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    q_opt = opt(args.sample_name, jid)
    cmd = "{job_home}/aln_3.markdup.sh {sample}".format(job_home=job_home, sample=args.sample_name)
    print('aln_3.markdup.sh\nq_opt:', q_opt, 'cmd:', cmd)
    jid = q.submit(q_opt, cmd) 
    #jid = q.submit(opt(args.sample_name, jid),
    #    "{job_home}/aln_3.markdup.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    q_opt = opt(args.sample_name, jid)
    cmd = "{job_home}/aln_4.indel_realign.sh {sample}".format(job_home=job_home, sample=args.sample_name)
    print('aln_4.indel_realign.sh\nq_opt:', q_opt, 'cmd:', cmd)
    jid = q.submit(q_opt, cmd) 
    #jid = q.submit(opt(args.sample_name, jid),
    #    "{job_home}/aln_4.indel_realign.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    q_opt = opt(args.sample_name, jid)
    cmd = "{job_home}/aln_5.bqsr.sh {sample}".format(job_home=job_home, sample=args.sample_name)
    print('aln_5.bqsr.sh\nq_opt:', q_opt, 'cmd:', cmd)
    jid = q.submit(q_opt, cmd) 
    #jid = q.submit(opt(args.sample_name, jid), 
    #    "{job_home}/aln_5.bqsr.sh {sample}".format(job_home=job_home, sample=args.sample_name))
    aln_jid = jid

    q_opt = opt(args.sample_name, aln_jid)
    cmd = "{job_home}/post_1.unmapped_reads.sh {sample}".format(job_home=job_home, sample=args.sample_name) 
    print('post_1.unmapped_reads.sh\nq_opt:', q_opt, 'cmd:', cmd)
    jid = q.submit(q_opt, cmd) 
    #jid = q.submit(opt(args.sample_name, aln_jid), 
    #    "{job_home}/post_1.unmapped_reads.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    save_hold_jid("{sample}/alignment/hold_jid".format(sample=args.sample_name), jid)

    q_opt = opt(args.sample_name, aln_jid)
    cmd = "{job_home}/post_2.run_variant_calling.sh {sample}".format(job_home=job_home, sample=args.sample_name)
    print('post_2.run_variant_calling.sh\nq_opt:', q_opt, 'cmd:', cmd)
    jid = q.submit(q_opt, cmd) 
    #jid = q.submit(opt(args.sample_name, aln_jid), 
    #    "{job_home}/post_2.run_variant_calling.sh {sample}".format(job_home=job_home, sample=args.sample_name))

    q_opt = opt(args.sample_name, jid)
    cmd = "{job_home}/post_3.upload_cram.sh {sample}".format(job_home=job_home, sample=args.sample_name)
    print('post_3.upload_cram.sh\nq_opt:', q_opt, 'cmd:', cmd)
    q.submit(q_opt, cmd) 
    #q.submit(opt(args.sample_name, jid), 
    #    "{job_home}/post_3.upload_cram.sh {sample}".format(job_home=job_home, sample=args.sample_name))

def parse_args():
    parser = argparse.ArgumentParser(description='Alignment job submitter')
    parser.add_argument('--sample-name', metavar='sample name', required=True)
    return parser.parse_args()

def opt(sample, jid=None):
    opt = "-r y -j y -o {log_dir} -l h_vmem=4G".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

if __name__ == "__main__":
    main()
