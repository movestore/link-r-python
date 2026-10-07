#!/bin/bash
# Produces the golden CSV pairs of test/contract/<case>/ from each <case>/input.rds, through two Apps:
#   input.rds --R->python--> meta.csv, link.csv, pickle --python->R--> py/meta.csv, py/link.csv
#
#   [R2PY_IMAGE=…] [PY2R_IMAGE=…] [CUT=1] [OVERLAY=1] test/contract/generate.sh
#
# Defaults to the v2.2.0 production images (registry access needed). CUT=1 first cuts every
# input.rds out of r/data/raw (see cut.R). OVERLAY: see test/images.sh.
set -o errexit -o nounset -o pipefail

cd "$(dirname "$0")/../.."
source test/images.sh

R2PY_IMAGE="${R2PY_IMAGE:-gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-a81e3046-bc48-4fcb-8d28-4291000c77f9-move2loc-to-movingpandas:7}"
PY2R_IMAGE="${PY2R_IMAGE:-gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-ed490356-9d55-4cb3-90d1-b8a2fc18ce10-movingpandas-to-move2loc:6}"
CUT="${CUT:-0}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/in"
cp -R test "$work/in/test"
cp -R r/data/raw "$work/in/raw"
runInImage "$R2PY_IMAGE" "$work/in" \
  "/tmp/in/test/contract/prepare.sh /tmp/in/raw /tmp/out $CUT && /tmp/in/test/roundtrip/r2python.sh ./start-process.sh /tmp/out/inputs /tmp/out/cases" \
  "$work/stage1"

cp -R test "$work/stage1/test"
runInImage "$PY2R_IMAGE" "$work/stage1" '/tmp/in/test/roundtrip/stage-python2r.sh /tmp/in/cases /tmp/out' "$work/stage2"

for dir in "$work"/stage1/contract/*/; do
  [ -f "$dir/input.rds" ] || continue
  case="$(basename "$dir")"
  for exit in "$work/stage1/cases/$case/r2python.exit" "$work/stage2/cases/$case/python2r.exit"; do
    if [ "$(cat "$exit")" != 0 ]; then
      echo "$case: $(basename "$exit" .exit) failed" >&2
      cat "${exit%.exit}.log" >&2
      exit 1
    fi
  done

  target="test/contract/$case"
  mkdir -p "$target/py"
  if [ "$CUT" = 1 ]; then
    cp "$dir/input.rds" "$target/input.rds"
  fi
  for file in meta.csv link.csv; do
    cp "$work/stage1/cases/$case/$file" "$target/$file"
    cp "$work/stage2/cases/$case/py/$file" "$target/py/$file"
  done
done
