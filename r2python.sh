#!/bin/bash --login
########################################################################################################################
# calls the co-pilot-r SDK entry point
########################################################################################################################
#set -o errexit
#set -o pipefail
#set -o nounset
# import for `conda activate`
set -e

#export SOURCE_FILE=/tmp/source_file
#export CONFIGURATION='{}'
#export OUTPUT_FILE=/tmp/go-home

#echo "$PATH"
#conda activate "$HOME"/co-pilot-r/python-env
#echo "after $PATH"
(cd r && Rscript rds_2_csv.R)
(cd python && conda activate "$HOME"/co-pilot-r/python-env && python csv_2_pickle.py)
