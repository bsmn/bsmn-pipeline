#!/usr/bin/env python3

import argparse
import subprocess
import sys

def ref_seq(chrom, pos1, pos2=None):
    if pos2 is None:
        site = "{chrom}:{pos}-{pos}".format(chrom=chrom, pos=pos1)
    else:
        site = "{chrom}:{start}-{end}".format(chrom=chrom, start=pos1, end=pos2)
    base = ''.join(subprocess.run(['samtools', 'faidx', ref_file, site], 
                          stdout=subprocess.PIPE, 
                          encoding="utf-8"
                         ).stdout.split("\n")[1:])
    return base

def repeat(chrom, pos, alt):
    read_size = 100
    read = ref_seq(chrom, int(pos)-read_size, int(pos)+read_size)
    alt_p = read_size
    w_max = 5
    n_max = 0
    for wsize in range(1, w_max + 1):
        for i in range(wsize):
            start = alt_p - wsize + 1 + i
            end = start + wsize

            word = read[start:alt_p] + alt + read[alt_p+1:end]
            
            n = 1
            while read[start-wsize:start] == word:
                start -= wsize
                n += 1

            while read[end:end+wsize] == word:
                end += wsize
                n += 1

            repeat_seq = "{}[{}>{}]{}".format(read[start:alt_p], read[alt_p], alt, read[alt_p+1:end])
            
            if n > n_max:
                repeat = "{}\t{}\t{}".format(n, end-start, repeat_seq)
                n_max = n

    return repeat

def run(args):
    global ref_file
    ref_file = args.ref

    header = '#chr\tpos\tref\talt\trepeat_n\trepeat_length\trepeat_seq'
    print(header, flush=True)
    for snv in args.infile:
        if snv[0] == '#':
            continue
        chrom, pos, ref, alt = snv.strip().split()[:4]
        print('{chrom}\t{pos}\t{ref}\t{alt}\t{repeat}'.format(
            chrom=chrom, pos=pos, ref=ref.upper(), alt=alt.upper(), 
            repeat=repeat(chrom, pos, alt.upper())), flush=True)

def main():
    parser = argparse.ArgumentParser(
        description='STR status around each SNV.')

    parser.add_argument(
        '-r', '--ref', metavar='FILE',
        help='reference seqeunce file',
        required=True)

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
