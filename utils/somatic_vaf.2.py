#!/usr/bin/env python3

import argparse
import os
import sys
from statsmodels.stats.proportion import binom_test 
from multiprocessing import Pool

pipe_home = os.path.dirname(os.path.realpath(__file__)) + "/.."
sys.path.append(pipe_home)
from library.misc import coroutine, printer
from library.pileup import load_config, base_count

def run(args):
    header = ('#chr\tpos\tref\talt\tvaf\t'
            + 'depth\tref_n\talt_n\tp_binom')
    printer(header)
    if args.nproc > 1:
        with Pool(args.nproc) as p:
            for r in p.starmap(_mpileup, [[args.bam, args.min_MQ, args.min_BQ] + snv.strip().split()[:4] for snv in args.infile if snv[0] != '#']):
                printer(r)
    else:
        v_info = vaf_info(base_count(args.bam, args.min_MQ, args.min_BQ))
        for snv in args.infile:
            if snv[0] == '#':
                continue
            chrom, pos, ref, alt = snv.strip().split()[:4]
            printer(mpileup(v_info, chrom, pos, ref, alt))
    sys.stdout.flush()

def _mpileup(bam, min_MQ, min_BQ, chrom, pos, ref, alt):
    return(mpileup(vaf_info(base_count(bam, min_MQ, min_BQ)), chrom, pos, ref, alt))

def mpileup(v_info, chrom, pos, ref, alt):
    return('{chrom}\t{pos}\t{ref}\t{alt}\t{vaf_info}'.format(
        chrom=chrom, pos=pos, ref=ref.upper(), alt=alt.upper(), 
        vaf_info=v_info.send((chrom, pos, ref, alt))))

@coroutine
def vaf_info(target):
    result = None
    while True:
        chrom, pos, ref, alt = (yield result)
        base_n = target.send((chrom, pos))
        depth = sum(base_n.values())
        ref_n = base_n[ref.upper()] + base_n[ref.lower()]
        alt_n = base_n[alt.upper()] + base_n[alt.lower()]
        try:
            vaf = alt_n/depth
        except ZeroDivisionError:
            vaf = 0
            
        result = '{vaf:f}\t{depth}\t{ref_n}\t{alt_n}\t{p_binom:e}'.format(
            vaf=vaf, depth=depth, ref_n=ref_n, alt_n=alt_n, p_binom=binom_test(alt_n, depth, alternative='smaller'))

def main():
    parser = argparse.ArgumentParser(
        description='Test whether VAF of each SNV is somatic or germline.')

    parser.add_argument(
        '-b', '--bam', metavar='FILE',
        help='bam file',
        required=True)

    parser.add_argument(
        '-r', '--reference', metavar='REFVER',
        help='reference genome to use', default=None)

    parser.add_argument(
        '-c', '--conda-env', metavar='CONDA_ENV',
        help='CONDA environment name to use', default=None)

    parser.add_argument(
        '-q', '--min-MQ', metavar='INT',
        help='mapQ cutoff value [20]',
        type=int, default=20)

    parser.add_argument(
        '-Q', '--min-BQ', metavar='INT',
        help='baseQ/BAQ cutoff value [13]',
        type=int, default=13)

    parser.add_argument(
        '-n', '--nproc', metavar='INT',
        help='Specifies the number of processors to use [default: 1]',
        type=int, default=1)
    
    parser.add_argument(
        'infile', metavar='snv_list.txt',
        help='''SNV list.
        Each line format is "chr\\tpos\\tref\\talt".
        Trailing columns will be ignored. [STDIN]''',
        nargs='?', type=argparse.FileType('r'),
        default=sys.stdin)

    parser.set_defaults(func=run)
    
    args = parser.parse_args()

    if args.reference is not None and args.conda_env is not None:
        load_config(args.reference, args.conda_env)

    if(len(vars(args)) == 0):
        parser.print_help()
    else:
        args.func(args)
        
if __name__ == "__main__":
    main()
