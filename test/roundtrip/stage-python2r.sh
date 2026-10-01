#!/bin/bash
# The other half, inside a python -> R App image: every pickle of <cases> back through the entry
# point $START (default ./start-process.sh), plus the python-born empty case -> <out>/cases/
set -o errexit -o nounset

here="$(cd "$(dirname "$0")" && pwd)"
cases="$1" out="$2"

mkdir -p "$out"
cp -R "$cases" "$out/cases"
"$here/empty.sh" "$out/cases"

"$here/python2r.sh" "${START:-./start-process.sh}" "$out/cases"
