#!/bin/bash
# Runs every <inputs>/<case>.rds through the R -> python entry point, as the platform would:
#   <cases>/<case>/{input.rds, meta.csv, link.csv, output.pickle, r2python.log, r2python.exit}
# Never fails itself: a failing App is a measurement, recorded in r2python.exit.
set -o nounset

start="$1" inputs="$2" cases="$3"

for input in "$inputs"/*.rds; do
  case="$(basename "$input" .rds)"
  dir="$cases/$case"
  mkdir -p "$dir"
  cp "$input" "$dir/input.rds"

  SOURCE_FILE="$dir/input.rds" OUTPUT_FILE="$dir/output.pickle" ERROR_FILE="$dir/error.log" \
    LINK_R_PYTHON_BUFFER="$dir/link.csv" LINK_R_PYTHON_META="$dir/meta.csv" \
    "$start" > "$dir/r2python.log" 2>&1
  echo $? > "$dir/r2python.exit"
done
