#!/usr/bin/env python3

import argparse
import os
import sys
from statsmodels.stats.proportion import binom_test 

pipe_home = os.path.dirname(os.path.realpath(__file__)) + "/.."
sys.path.append(pipe_home)
from library.misc import coroutine, printer
from library.pileup import load_config, base_qual_tuple

def run(args):
    alt_BQ_info = alt_BQ_sum(base_qual_tuple(args.bam, args.min_MQ, args.min_BQ))
    header = '#chr\tpos\tref\talt\talt_n\talt_BQ_sum'
    printer(header)
    for snv in args.infile:
        if snv[0] == '#':
            continue
        chrom, pos, ref, alt = snv.strip().split()[:4]
        printer('{chrom}\t{pos}\t{ref}\t{alt}\t{alt_BQ_info}'.format(
            chrom=chrom, pos=pos, ref=ref.upper(), alt=alt.upper(), 
            alt_BQ_info=alt_BQ_info.send((chrom, pos, alt))))

@coroutine
def alt_BQ_sum(target):
    result = None
    while True:
        chrom, pos, alt = (yield result)
        alt_BQ = [q for b, q in target.send((chrom, pos)) if b == alt.upper()]
        result = '{alt_n}\t{alt_BQ_sum}'.format(alt_n=len(alt_BQ), alt_BQ_sum=sum(alt_BQ))

def main():
    parser = argparse.ArgumentParser(
        description='Sum of base qualities of alt allele of each SNV')

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
