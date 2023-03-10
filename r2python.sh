#!/bin/bash --login
########################################################################################################################
# converts from R .rds to Python .pickle
########################################################################################################################
#set -o errexit
#set -o pipefail
#set -o nounset
set -e

(cd r && Rscript rds_2_csv.R)
(cd python && conda activate "$HOME"/co-pilot-r/python-env && python csv_2_pickle.py)
