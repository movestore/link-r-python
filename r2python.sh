#!/bin/bash --login
########################################################################################################################
# calls the co-pilot-r SDK entry point
########################################################################################################################
set -o errexit
set -o pipefail
set -o nounset

conda activate "$HOME"/co-pilot-r/python-env

Rscript r/rds_to_csv.R
python python/csv_2_pickle.py
