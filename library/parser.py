import os
from collections import defaultdict

def filetype(fname):
    root, ext = os.path.splitext(fname)
    ext = os.path.splitext(root)[1] if ext == ".gz" else ext

    if ext == ".bam" or ext == ".bai":
        ftype = "bam"
    elif ext == ".cram" or ext == ".crai":
        ftype = "cram"
    elif ext == ".fastq" or ext == ".fq":
        ftype = "fastq"
    else:
        raise Exception(ext + " is not allowed filetype in the sample list")

    return ftype

def sample_list(fname):
    samples = defaultdict(list)
    with open(fname) as sfile:
        for line in sfile:
            if line[0] == "#":
                continue
            sample_id, file_name, location = line.strip().split()[:3]
            samples[(sample_id, filetype(file_name))].append((file_name, location))
    return samples
