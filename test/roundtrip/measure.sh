#!/bin/bash
# Measures what a round trip R -> python -> R does to every sample input, and pins it:
#   test/roundtrip/expected.csv - per case: exit codes, rows and tracks out, time deviation, time column and tzone out
#   test/roundtrip/classes.csv  - per case and column: class in, class out
#
#   [R2PY_IMAGE=…] [PY2R_IMAGE=…] [OVERLAY=1] [KEEP=<dir>] test/roundtrip/measure.sh
#
# Defaults to the v2.2.0 production images (registry access needed). KEEP copies the cases out,
# outputs included. OVERLAY: see test/images.sh.
set -o errexit -o nounset -o pipefail

cd "$(dirname "$0")/../.."
source test/images.sh

R2PY_IMAGE="${R2PY_IMAGE:-gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-a81e3046-bc48-4fcb-8d28-4291000c77f9-move2loc-to-movingpandas:7}"
PY2R_IMAGE="${PY2R_IMAGE:-gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-ed490356-9d55-4cb3-90d1-b8a2fc18ce10-movingpandas-to-move2loc:6}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# R -> python: sample inputs and synthetic cases
mkdir -p "$work/in/raw"
cp r/data/raw/*move2loc*.rds "$work/in/raw/"
cp -R test "$work/in/test"
runInImage "$R2PY_IMAGE" "$work/in" '/tmp/in/test/roundtrip/stage-r2python.sh /tmp/in/raw /tmp/out' "$work/stage1"

# python -> R, then describe with that image's R
cp -R test "$work/stage1/test"
runInImage "$PY2R_IMAGE" "$work/stage1" \
  '/tmp/in/test/roundtrip/stage-python2r.sh /tmp/in/cases /tmp/out && cd r && Rscript /tmp/in/test/roundtrip/describe.R /tmp/out/cases /tmp/out/expected.csv /tmp/out/classes.csv' \
  "$work/stage2"

cp "$work/stage2/expected.csv" "$work/stage2/classes.csv" test/roundtrip/
if [ -n "${KEEP:-}" ]; then
  rm -rf "$KEEP"
  cp -R "$work/stage2/cases" "$KEEP"
fi
