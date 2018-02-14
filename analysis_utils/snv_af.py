#!/shared/apps/pyenv/versions/3.6.2/bin/python

import argparse
import re
import subprocess
import sys
import os


def print_af(args):
    af_routines = [calc_af(pileup(args.clone, args.min_MQ, args.min_BQ, clean(count())))]
    header = '#chr\tpos\tref\talt\tcl_af\tcl_depth\tcl_ref_n\tcl_alt_n\tcl_base_count'
    if args.tissue != None:
        af_routines.append(calc_af(pileup(args.tissue, args.min_MQ, args.min_BQ, clean(count()))))
        header = header + '\tti_af\tti_depth\tti_ref_n\tti_alt_n\tti_base_count'
    printer(header)
    for snv in args.infile:
        if snv[0] == '#':
            continue
        chrom, pos, ref, alt = snv.strip().split()[:4]
        af = '\t'.join([af_routine.send((chrom, pos, ref, alt)) for af_routine in af_routines])
        printer('{}\t{}\t{}\t{}\t{}'.format(chrom, pos, ref.upper(), alt.upper(), af))
        
            
def coroutine(func):
    def start(*args, **kwargs):
        g = func(*args, **kwargs)
        g.__next__()
        return g
    return start

@coroutine
def calc_af(target):
    result = None
    while True:
        chrom, pos, ref, alt = (yield result)
        base_n = target.send((chrom, pos))
        total = sum(base_n.values())
        ref_n = base_n[ref.upper()] + base_n[ref.lower()]
        alt_n = base_n[alt.upper()] + base_n[alt.lower()]
        try:
            af = alt_n / total
        except ZeroDivisionError:
            af = 0
        result = '{:f}\t{}\t{}\t{}\tA={A},C={C},G={G},T={T},a={a},c={c},g={g},t={t},dels={dels}'.format(
            af, total, ref_n, alt_n, **base_n)

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
        
def main():
    parser = argparse.ArgumentParser(
        description='Calculate allele freqeuency for SNV')

    parser.add_argument(
        '-c', '--clone', metavar='FILE',
        help='clone bam file',
        required=True)

    parser.add_argument(
        '-t', '--tissue', metavar='FILE',
        help='tissue bam file')

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

    parser.set_defaults(func=print_af)
    
    args = parser.parse_args()

    if(len(vars(args)) == 0):
        parser.print_help()
    else:
        args.func(args)
        
if __name__ == "__main__":
    main()
