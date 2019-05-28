import os
import sys
import re
import shutil
import subprocess
from .config import read_config
from .misc import coroutine

config = read_config()
SAMTOOLS = config["TOOLS"]["SAMTOOLS"]
if not os.path.isfile(SAMTOOLS) or not os.access(SAMTOOLS, os.X_OK):
    SAMTOOLS = shutil.which("samtools")

def base_count(bam, min_MQ, min_BQ):
    return pileup(bam, min_MQ, min_BQ, base_n())

def base_qual_tuple(bam, min_MQ, min_BQ):
    return pileup(bam, min_MQ, min_BQ, base_qual())

@coroutine
def pileup(bam, min_MQ, min_BQ, target):
    result = None
    while True:
        chrom, pos = (yield result)
        cmd = [SAMTOOLS, 'mpileup', '-d', '8000',
               '-q', str(min_MQ), '-Q', str(min_BQ),
               '-r', '{}:{}-{}'.format(chrom, pos, pos), bam]
        
        max_retries = 5
        n_retries = 0
        while True:
            cmd_out = subprocess.run(
                cmd, universal_newlines=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                cmd_out.check_returncode()
                break
            except subprocess.CalledProcessError:
                if n_retries == 0: sys.stderr.write("\n")
                sys.stderr.write("{pileup_err}source bam: {bam}\npileup location: {chrom}:{pos}-{pos}\n".format(
                    pileup_err=cmd_out.stderr, bam=bam, chrom=chrom, pos=pos))
                if n_retries < max_retries:
                    n_retries += 1
                    sys.stderr.write("Retry pileup...\n")
                else:
                    sys.exit("Failed in pileup.")
        try:
            bases, quals = cmd_out.stdout.split()[4:6]
            bases = bases_clean(bases)
        except ValueError:
            bases, quals = ('', '')
        result = target.send((bases, quals))

def bases_clean(bases):
    bases = re.sub('\^.', '', bases)
    bases = re.sub('\$', '', bases)
    for n in set(re.findall('-(\d+)', bases)):
        bases = re.sub('-{0}[ACGTNacgtn]{{{0}}}'.format(n), '', bases)
    for n in set(re.findall('\+(\d+)', bases)):
        bases = re.sub('\+{0}[ACGTNacgtn]{{{0}}}'.format(n), '', bases)
    return bases

@coroutine
def base_n():
    result = None
    while True:
        bases, quals = (yield result)
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

@coroutine
def base_qual():
    result = None
    while True:
        bases, quals = (yield result)
        bases = re.sub('\*', '', bases)
        result = list(map(lambda b, q: (b.upper(), ord(q)-33), bases, quals))
