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

# Contributing

The `master` branch is protected. To make introduce changes:

1. Fork this repository
2. Open a branch with your github username and a short descriptive statement (like `kdaily-update-readme`). If there is an open issue on this repository, name your branch after the issue (like `kdaily-issue-7`).
3. Open a pull request and request a review.
