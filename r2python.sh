#!/bin/bash --login
########################################################################################################################
# calls the co-pilot-r SDK entry point
########################################################################################################################
set -o errexit
set -o pipefail
set -o nounset

conda activate "$HOME"/co-pilot-r/python-env

(cd r && Rscript r/rds_2_csv.R)
python python/csv_2_pickle.py
