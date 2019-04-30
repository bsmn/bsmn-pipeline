import os
from collections import defaultdict

def filetype(fname):
    return "bam" if os.path.splitext(fname)[1] == ".bam" else "fastq"

def sample_list(fname):
    samples = defaultdict(list)
    with open(fname) as sfile:
        for line in sfile:
            if line[0] == "#":
                continue
            sample_id, file_name, location = line.strip().split()[:3]
            samples[(sample_id, filetype(file_name))].append((file_name, location))
    return samples

def sample_list2(fname):
    samples = defaultdict(list)
    with open(fname) as sfile:
        for line in sfile:
            if line[0] == "#":
                continue
            sample_id, file_name, location = line.strip().split()[:3]
            samples[sample_id].append((file_name, location))
    return samples
