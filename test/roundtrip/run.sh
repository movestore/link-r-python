#!/bin/bash
# Inside the test image, which holds both entry points: the round trip of every case, checked against
# expected.csv and classes.csv.
#   r/data/raw/*.rds --start-process.sh--> pickle --start-process-python2r.sh--> rds
set -o errexit -o nounset

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"

"$here/stage-r2python.sh" r/data/raw "$work/stage1"
START=./start-process-python2r.sh "$here/stage-python2r.sh" "$work/stage1/cases" "$work/stage2"

(cd r && Rscript "$here/compare.R" "$work/stage2/cases" "$here/expected.csv" "$here/classes.csv")
