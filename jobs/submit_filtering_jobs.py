#!/usr/bin/env python3

import argparse
import glob
import os
import sys

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/variant_filtering"
sys.path.append(pipe_home)

from library.config import log_dir, save_hold_jid
from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()
    q.set_run_jid(args.sample_name + "/run_jid")

    jid_cnvnator = q.submit(opt(args.sample_name),
        ("{job_home}/A.CNVnator_mk_root.malign.sh {sample} {sample_list} 100" if args.multiple_alignments else "{job_home}/A.CNVnator_mk_root.sh {sample} 100").format(
            job_home=job_home, sample=args.sample_name, sample_list=args.sample_list))

    for ploidy in args.ploidy:
        submit_jobs(args.sample_name, ploidy, args.sample_list, args.multiple_alignments, jid_cnvnator)
    
def parse_args():
    parser = argparse.ArgumentParser(description='Variant filtring job submitter')
    parser.add_argument('--ploidy', metavar='int', nargs='+', type=int, default=2)
    parser.add_argument('--sample-name', metavar='sample name', required=True)
    parser.add_argument('--sample-list', metavar='sample list file', required=True)
    parser.add_argument('--multiple-alignments', action='store_true', default=False)
    return parser.parse_args()

def opt(sample, jid=None):
    opt = "-V -q 1-day -r y -j y -o {log_dir}".format(log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def submit_jobs(sample, ploidy, sample_list, malign, jid_cnvnator):
    jid = q.submit(opt(sample),
        "{job_home}/A.gnomAD_germline_filter.sh {sample} {ploidy}".format(job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid),
        "{job_home}/B.PASS_P.sh {sample} {ploidy}".format(job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid),
        ("{job_home}/C.VAF_filters.malign.sh {sample} {sample_list} {ploidy}" if malign else "{job_home}/C.VAF_filters.sh {sample} {ploidy}").format(
            job_home=job_home, sample=sample, sample_list=sample_list, ploidy=ploidy))
    jid_cnv = q.submit(opt(sample, ",".join([jid_cnvnator, jid])),
        "{job_home}/D.CNVnator_genotype_filter.sh {sample} {ploidy} 100".format(job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid_cnv),
        ("{job_home}/E.mayo_filters.malign.sh {sample} {sample_list} {ploidy}" if malign else "{job_home}/E.mayo_filters.sh {sample} {ploidy}").format(
            job_home=job_home, sample=sample, sample_list=sample_list, ploidy=ploidy))
    jid_mayo_pon = q.submit(opt(sample, jid),
        "{job_home}/F.PON_mask.sh {sample} {ploidy} mayo".format(job_home=job_home, sample=sample, ploidy=ploidy))
    jid = q.submit(opt(sample, jid_cnv),
        ("{job_home}/E.MosaicForecast.malign.sh {sample} {sample_list} {ploidy}" if malign else "{job_home}/E.MosaicForecast.sh {sample} {ploidy}").format(
            job_home=job_home, sample=sample, sample_list=sample_list, ploidy=ploidy))
    jid_mosaic_pon = q.submit(opt(sample, jid),
        "{job_home}/F.PON_mask.sh {sample} {ploidy} mosaic".format(job_home=job_home, sample=sample, ploidy=ploidy))
    return [jid_mayo_pon, jid_mosaic_pon]

if __name__ == "__main__":
    main()
