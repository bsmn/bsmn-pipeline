#!/shared/apps/pyenv/versions/3.6.2/bin/python

import argparse
import re
import subprocess
import sys
import os
import math 
from rpy2.robjects import r
from scipy.stats import fisher_exact

def run(args):
    s_info = strand_info(pileup(args.bam, args.min_MQ, args.min_BQ, clean(count())))
    header = ('#chr\tpos\tref\talt\t'
            + 'total\ttotal_fwd\ttotal_rev\ttotal_ratio\t'
            + 'p_poisson\t'
            + 'ref_n\tref_fwd\tref_rev\tref_ratio\t'
            + 'alt_n\talt_fwd\talt_rev\talt_ratio\t'
            + 'p_fisher')
    printer(header)
    for snv in args.infile:
        if snv[0] == '#':
            continue
        chrom, pos, ref, alt = snv.strip().split()[:4]
        printer('{chrom}\t{pos}\t{ref}\t{alt}\t{strand_info}'.format(
            chrom=chrom, pos=pos, ref=ref.upper(), alt=alt.upper(), 
            strand_info=s_info.send((chrom, pos, ref, alt))))

def coroutine(func):
    def start(*args, **kwargs):
        g = func(*args, **kwargs)
        g.__next__()
        return g
    return start

@coroutine
def strand_info(target):
    result = None
    while True:
        chrom, pos, ref, alt = (yield result)
        base_n = target.send((chrom, pos))
        total = sum(base_n.values())
        total_fwd = sum(list(base_n.values())[:4])
        total_rev = sum(list(base_n.values())[4:8])
        try:
            total_ratio = total_fwd/total_rev
        except ZeroDivisionError:
            total_ratio = math.inf
        ref_n = base_n[ref.upper()] + base_n[ref.lower()]
        ref_fwd = base_n[ref.upper()]
        ref_rev = base_n[ref.lower()]
        try:
            ref_ratio = ref_fwd/ref_rev
        except ZeroDivisionError:
            ref_ratio = math.inf
        alt_n = base_n[alt.upper()] + base_n[alt.lower()]
        alt_fwd = base_n[alt.upper()]
        alt_rev = base_n[alt.lower()]
        try:
            alt_ratio = alt_fwd/alt_rev
        except ZeroDivisionError:
            alt_ratio = math.inf
            
        result = ('{total}\t{total_fwd}\t{total_rev}\t{total_ratio:f}\t'
                + '{p_poisson:f}\t' 
                + '{ref_n}\t{ref_fwd}\t{ref_rev}\t{ref_ratio:f}\t'
                + '{alt_n}\t{alt_fwd}\t{alt_rev}\t{alt_ratio:f}\t'
                + '{p_fisher:f}').format(
            total=total, total_fwd=total_fwd, total_rev=total_rev, total_ratio=total_ratio, 
            p_poisson=p_poisson(total_fwd, total_rev),
            ref_n=ref_n, ref_fwd=ref_fwd, ref_rev=ref_rev, ref_ratio=ref_ratio,
            alt_n=alt_n, alt_fwd=alt_fwd, alt_rev=alt_rev, alt_ratio=alt_ratio, 
            p_fisher=p_fisher(ref_fwd, alt_fwd, ref_rev, alt_rev))

@coroutine
def pileup(bam, min_MQ, min_BQ, target):
    result = None
    while True:
        chrom, pos = (yield result)
        cmd = ['samtools', 'mpileup', '-d', '8000',
               '-q', str(min_MQ), '-Q', str(min_BQ),
               '-r', '{}:{}-{}'.format(chrom, pos, pos), bam]
        cmd_out = subprocess.run(
            cmd, universal_newlines=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            cmd_out.check_returncode()
        except subprocess.CalledProcessError:
            sys.exit(cmd_out.stderr)
        try:
            bases = cmd_out.stdout.split()[4]
        except IndexError:
            bases = ''
        result = target.send(bases)

@coroutine
def clean(target):
    result = None
    while True:
        bases = (yield result)
        bases = re.sub('\^.', '', bases)
        bases = re.sub('\$', '', bases)
        for n in set(re.findall('-(\d+)', bases)):
            bases = re.sub('-{0}[ACGTNacgtn]{{{0}}}'.format(n), '', bases)
        for n in set(re.findall('\+(\d+)', bases)):
            bases = re.sub('\+{0}[ACGTNacgtn]{{{0}}}'.format(n), '', bases)
        result = target.send(bases)

@coroutine
def count():
    result = None
    while True:
        bases = (yield result)
        base_n = {}
        base_n['A'] = bases.count('A') 
        base_n['C'] = bases.count('C')
        base_n['G'] = bases.count('G')
        base_n['T'] = bases.count('T')
        base_n['a'] = bases.count('a')
        base_n['c'] = bases.count('c')
        base_n['g'] = bases.count('g')
        base_n['t'] = bases.count('t')
        base_n['dels'] = bases.count('*')
        result = base_n

def printer(out):
    try:
        print(out, flush=True)
    except BrokenPipeError:
        try:
            sys.stdout.close()
        except BrokenPipeError:
            pass
        try:
            sys.stderr.close()
        except BrokenPipeError:
            pass

def p_poisson(n_fwd, n_rev):
    return r("poisson.test(c({},{}))$p.value".format(n_fwd, n_rev))[0]

def p_fisher(ref_fwd, alt_fwd, ref_rev, alt_rev):
    return fisher_exact([[ref_fwd, alt_fwd], [ref_rev, alt_rev]])[1]

def main():
    parser = argparse.ArgumentParser(
        description='Check strand bias for SNV')

    parser.add_argument(
        '-b', '--bam', metavar='FILE',
        help='bam file',
        required=True)

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

    if(len(vars(args)) == 0):
        parser.print_help()
    else:
        args.func(args)
        
if __name__ == "__main__":
    main()
