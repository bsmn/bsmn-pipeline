#!/usr/bin/env python3

import sys
import argparse
import functools
import gzip
import re

print = functools.partial(print, flush=True)

parser = argparse.ArgumentParser(description='Known germline variant filter')
parser.add_argument('infile', help='VCF file', nargs='?', 
                    type=argparse.FileType('r'), default=sys.stdin)
parser.add_argument('--variant', '-V', help='gzipped variant file (format:chrom\\tpos\\t\\tref\\talt)', required=True)

args = parser.parse_args()

known_germ = set()
with gzip.open(args.variant, 'rt') as f:
    for line in f:
        known_germ.add(":".join(line.strip().split()))

for line in args.infile:
    if line[0] == '#':
        print(line, end='')
        continue
    chrom, pos, _, ref, alts = line.split()[:5]
    for alt in alts.split(','):
        var = "{chrom}:{pos}:{ref}:{alt}".format(chrom=re.sub('^chr', '', chrom), pos=pos, ref=ref, alt=alt)
        if var not in known_germ:
            print(line, end='')
sys.stdout.flush()

