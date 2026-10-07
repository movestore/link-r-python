#!/bin/bash
# Inside the R -> python image: collects every <contract>/<case>/input.rds as <out>/inputs/<case>.rds,
# after cutting them from <raw> first when <cut> is 1.
set -o errexit -o nounset

here="$(cd "$(dirname "$0")" && pwd)"
raw="$1" out="$2" cut="$3"

mkdir -p "$out/contract" "$out/inputs"
cp -R "$here/." "$out/contract/"
if [ "$cut" = 1 ]; then
  (cd r && Rscript "$here/cut.R" "$raw" "$out/contract")
fi

for dir in "$out"/contract/*/; do
  [ -f "$dir/input.rds" ] || continue
  cp "$dir/input.rds" "$out/inputs/$(basename "$dir").rds"
done
