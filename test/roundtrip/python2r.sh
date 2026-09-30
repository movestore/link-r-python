#!/bin/bash
# Runs every <cases>/<case>/output.pickle through the python -> R entry point:
#   <cases>/<case>/{py/meta.csv, py/link.csv, output.rds, python2r.log, python2r.exit}
# A case without a pickle (its R -> python step failed) is skipped.
set -o nounset

start="$1" cases="$2"

for dir in "$cases"/*/; do
  dir="${dir%/}"
  [ -f "$dir/output.pickle" ] || continue
  mkdir -p "$dir/py"

  SOURCE_FILE="$dir/output.pickle" OUTPUT_FILE="$dir/output.rds" ERROR_FILE="$dir/py/error.log" \
    LINK_R_PYTHON_BUFFER="$dir/py/link.csv" LINK_R_PYTHON_META="$dir/py/meta.csv" \
    "$start" > "$dir/python2r.log" 2>&1
  echo $? > "$dir/python2r.exit"
done
