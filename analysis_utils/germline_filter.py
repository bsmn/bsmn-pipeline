#!/usr/bin/env python3

import os
import sys
import argparse
import subprocess
import functools

config = os.path.dirname(os.path.realpath(__file__)) + "/../pipeline.conf"
with open(config) as f:
    for line in f:
        if line[:6] == "TABIX=":
            TABIX=line.strip().split('=')[1]
            break

print = functools.partial(print, flush=True)

parser = argparse.ArgumentParser(description='Germline DB filter')
parser.add_argument('infile', help='VCF file', nargs='?', 
                    type=argparse.FileType('r'), default=sys.stdin)
parser.add_argument('--variant', '-V', help='gzipped variant file (format:chrom\\tpos\\t\\tref\\talt)', required=True)

args = parser.parse_args()
in_vcf = args.infile

def check_known_germ(chrom, pos, ref, alt, germ_file=args.variant):
    germ_out = subprocess.run([TABIX, germ_file, '{0}:{1}-{1}'.format(chrom, pos)], 
                             stdout=subprocess.PIPE).stdout.decode().split('\n')
    for line in germ_out:
        if line == '':
            break
        else:
            germ_ref, germ_alt = line.split('\t')[2:4]
            if ref == germ_ref and alt == germ_alt:
                return True
    return False

for line in in_vcf:
    if line[0] == '#':
        print(line, end='')
        continue
    chrom, pos, _, ref, alts = line.split()[:5]
    for alt in alts.split(','):
        if check_known_germ(chrom, pos, ref, alt):
            continue
        else:
            print(line, end='')
            break
