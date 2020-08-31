import os
import sys
import re
import pandas as pd
from multiprocessing import Pool

inf = sys.argv[1]#tab delimited file with hg38 chromosome, position, reference and alternative bases
outf = sys.argv[2]
cram_dir = sys.argv[3]
procs = int(sys.argv[4])

data_pd = pd.read_csv(inf,sep='\t',dtype={'chrm':str},names=['chrm','pos','ref','alt'])
#print (data_pd)

bam_li = []
bam_name_li = []
bams = os.listdir(cram_dir)
for bam in bams:
     if 'crai' not in bam and 'fai' not in bam:
         bam_li.append(bam)
         bam_name_li.append(bam.split('.')[0])
#bam_li = bam_li[0:5]
#bam_name_li = bam_name_li[0:5]
#print (bam_li)

def bases_clean(bases):
    '''
    Remove following pileups:
      - Flags for start and end positions of reads
      - ASCII code for quality of the read
      - pileups for INDELs e.g. [+-][1-9]+[ATGCatgc]+
    '''
    bases = re.sub('\^.', '', bases)
    bases = re.sub('\$', '', bases)
    for n in set(re.findall('-(\d+)', bases)):
        bases = re.sub('-{0}[ACGTNacgtn]{{{0}}}'.format(n), '', bases)
    for n in set(re.findall('\+(\d+)', bases)):
        bases = re.sub('\+{0}[ACGTNacgtn]{{{0}}}'.format(n), '', bases)
    return bases

def count_site(chrm,pos,bam,ref,alt):
    count_dict = {ref:0,
    alt:0}
    #print (chrm)
    #print (pos)
    a = os.popen(f'samtools mpileup {bam} -r {chrm}:{pos}-{pos} -Q 20 -q 20')
    a = a.read().rstrip().split('\t')
    #print (a)
    if len(a) < 5:
        return count_dict
    base_string = a[4]
    # Remove pileups for INDELs
    base_string = bases_clean(base_string);
    base_string = base_string.upper()
    #print (base_string)
    if base_string == ['']:
        return count_dict
    else:
        count_dict[ref] = base_string.count(ref)
        count_dict[alt] = base_string.count(alt)
        '''i = 0
        while True:
            if i >= len(base_string):
                break
            base = base_string[i]
            if base == '$':
                i += 2
                continue
            elif base == '^':
                #i+=2 if want to skip the reads start with this base
                i += 1
                continue
            elif base == '+':
                number = int(base_string[i + 1])
                number += 2
                i += number
            elif base in ['A', 'T', 'C', 'G']:
                count_dict[base] += 1
                i += 1
            elif base in ['a', 't', 'c', 'g']:
                count_dict[base.upper()] += 1
                i += 1
            else:
                i += 1
                continue'''
    return count_dict

def calc_CAF(count_dict,alt,cov):
    if cov == 0:
        return 0
    else:
        return  count_dict[alt]/cov   
base_li = ['A','C','G','T']
ori_columns = list(data_pd.columns)
ori_columns.append('PON1kg')

def calc_freq(i, line):
    chrm38 = line['chrm']
    pos38 = line['pos']
    ref = line['ref']
    alt = line['alt']
    data_pd = pd.DataFrame()
    for bam in bam_li:
        #print (bam)
        name = bam.split('.')[0]
        count_dict = count_site(chrm38,pos38,f'{cram_dir}/{bam}',ref,alt)
        cov = 0
        for base in [ref,alt]:
            data_pd.loc[(i,f'{name}.{base}')] = count_dict[base]
            cov += count_dict[base]
        freq = calc_CAF(count_dict,alt,cov)
        data_pd.loc[(i,f'{name}.CAF')] = freq
    return data_pd

with Pool(procs) as p:
    data_pd = pd.concat((data_pd, pd.concat(p.starmap(calc_freq, data_pd.iterrows()), ignore_index = True, sort = False)), axis = 1)
print (data_pd)

#for i,line in data_pd.iterrows():
#    chrm38 = line['chrm']
#    pos38 = line['pos']
#    ref = line['ref']
#    alt = line['alt']
#    for bam in bam_li:
#        #print (bam)
#        name = bam.split('.')[0]
#        count_dict = count_site(chrm38,pos38,f'{cram_dir}/{bam}',ref,alt)
#        cov = 0
#        for base in [ref,alt]:
#            data_pd.loc[(i,f'{name}.{base}')] = count_dict[base]
#            cov += count_dict[base]
#        freq = calc_CAF(count_dict,alt,cov)
#        data_pd.loc[(i,f'{name}.CAF')] = freq
#print (data_pd)
for i,line in data_pd.iterrows():
    num = 0
    for name in bam_name_li:
        if line[f'{name}.CAF'] > 0.05:
            num+=1
    if num > 5:
        data_pd.loc[(i,'PON1kg')] = 'Fail'
    else:
        data_pd.loc[(i,'PON1kg')] = 'Pass'
data_pd = data_pd[ori_columns]
data_pd.to_csv(outf,index=False,sep='\t')
print ('PON done')
