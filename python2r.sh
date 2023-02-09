#!/bin/bash --login
########################################################################################################################
# converts from Python .pickle to R .rds
########################################################################################################################
#set -o errexit
#set -o pipefail
#set -o nounset
set -e

(cd python && conda activate "$HOME"/co-pilot-r/python-env && python pickle_2_csv.py)
(cd r && Rscript csv_2_rds.R)
