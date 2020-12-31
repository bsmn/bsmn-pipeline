#!/usr/bin/env python3

import argparse
import os
import sys
from collections import defaultdict, deque

cmd_home = os.path.dirname(os.path.realpath(__file__))
pipe_home = os.path.normpath(cmd_home + "/..")
job_home = cmd_home + "/variant_filtering"
sys.path.append(pipe_home)

from library.config import run_info, run_info_append, log_dir
from library.parser import sample_list
from library.job_queue import GridEngineQueue
q = GridEngineQueue()

def main():
    args = parse_args()

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
        run_info_append(f_run_info, "SKIP_CNVNATOR={}".format(args.skip_cnvnator))
        run_info_append(f_run_info, "RUN_FILTERS={}".format(args.run_filters))
        run_info_append(f_run_info, "MULTI_ALIGNS={}".format(len(sdata) > 1))
        if args.run_gatk_hc:
            ploidy = " ".join(str(i) for i in args.run_gatk_hc)
            run_info_append(f_run_info, "RUN_GATK_HC=True\nPLOIDY=\"{}\"".format(ploidy))
        else:
            run_info_append(f_run_info, "RUN_GATK_HC={}".format(args.run_gatk_hc))

        #if filetype == "fastq":
        #    raise Exception("The input filetype should be bam or cram.")

        if args.vcf_directory is not None:
            q.submit(opt(sample, args.queue),
                "{job_home}/prep/start_variant_filtering.sh {sample} {vcf_dir}".format(
                    job_home=job_home, sample=sample, vcf_dir=args.vcf_directory))
        else:
            q.submit(opt(sample, args.queue),
                "{job_home}/prep/start_variant_filtering.sh {sample}".format(job_home=job_home, sample=sample))

        print()

def opt(sample, Q, jid=None):
    opt = "-V -q {q} -r y -j y -o {log_dir} -l h_vmem=4G".format(q=Q, log_dir=log_dir(sample))
    if jid is not None:
        opt = "-hold_jid {jid} {opt}".format(jid=jid, opt=opt)
    return opt

def parse_args():
    parser = argparse.ArgumentParser(description='Variant Filtering Pipeline')
    parser.add_argument('-q', '--queue', metavar='queue', required=True,
        help='''Specify the queue name of Sun Grid Engine for jobs to be submitted''')
    parser.add_argument('-n', '--conda-env', metavar='env',
        help='''Specify the name of conda environment for pipeline [default is bp]''', default="bp")
    parser.add_argument('-p', '--run-gatk-hc', metavar='ploidy', type=int, nargs='+', default=False)
    parser.add_argument('--skip-cnvnator', action='store_true', default=False)
    parser.add_argument('--run-filters', action='store_true', default=True)
    parser.add_argument('-f', '--align-fmt', metavar='fmt',
        help='''Alignment format [cram (default) or bam]''', default="cram")
    parser.add_argument('-r', '--reference', metavar='ref',
        help='''Reference version [b37 (default) or hg19]''', default="b37")
    parser.add_argument('-v', '--vcf-directory', metavar='dir',
        help='''Specify a directory where existing VCF files are, if you have.
        VCF file for each ploidy will be linked into the sample directory before running the filtering.
        VCF and index file names must be formed as follows:
            <sample name>.ploidy_<ploidy>.vcf.gz
            <sample name>.ploidy_<ploidy>.vcf.gz.tbi
        [Default: None]''', default=None)
    parser.add_argument('--sample-list', metavar='sample_list.txt', required=True,
        help='''Sample list file.
        Each line format is "sample_id\\tfile_name\\tlocation".
        Lines staring with "#" will omitted.
        Header line should also start with "#".
        Trailing columns will be ignored.''')
    return parser.parse_args()

if __name__ == "__main__":
    main()
