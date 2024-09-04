#!/bin/bash --login
########################################################################################################################
# converts from R .rds to Python .pickle
########################################################################################################################
#set -o errexit
#set -o pipefail
#set -o nounset
set -e

set -a
# do not provide the buffer (link.csv) as artifact; it is too big and not really useful
: ${LINK_R_PYTHON_BUFFER:=/tmp/link.csv}
: ${LINK_R_PYTHON_META:=/tmp/artifacts/meta.csv}
set +a

(cd r && Rscript rds_2_csv.R)
(cd python && conda activate "$HOME"/co-pilot-r/python-env && python csv_2_pickle.py)
