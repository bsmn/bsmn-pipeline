# bsmn_pipeline
BSMN common data processing pipeline

# Usage
## genome_mapping
```bash
genome_mapping/run.py sample_list.txt
```

### sample_list.txt format
The first line should be a header line. Eg.
```
sample_id       file    synapse_id
5154_brain-BSMN_REF_brain-534-U01MH106876       bulk_sorted.bam syn10639574
5154_fibroblast-BSMN_REF_fibroblasts-534-U01MH106876    fibroblasts_sorted.bam  syn10639575
```
