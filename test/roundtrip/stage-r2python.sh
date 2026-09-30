#!/bin/bash
# One half of the round trip, inside an R -> python App image: the sample inputs of <raw> plus the
# synthetic cases through the entry point $START (default ./start-process.sh) -> <out>/cases/
set -o errexit -o nounset

here="$(cd "$(dirname "$0")" && pwd)"
raw="$1" out="$2"

mkdir -p "$out/inputs"
cp "$raw"/*move2loc*.rds "$out/inputs/"
(cd r && Rscript "$here/synthetic.R" "$out/inputs/input1_move2loc_LatLon.rds" "$out/inputs")

"$here/r2python.sh" "${START:-./start-process.sh}" "$out/inputs" "$out/cases"
