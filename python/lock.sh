#!/bin/bash
# Resolves python/environment.yml into python/conda-linux-64.lock - the explicit package list the App and
# the python tests install, so an App version gets exactly what CI tested. Run before every release,
# and after any change to environment.yml:
#   python/lock.sh
# Resolves for linux-64, the platform's architecture, with the Miniforge of test/Dockerfile (the python
# co-pilot's base). The first line holds the md5 of environment.yml; test/coherence.R holds them together.
set -o errexit -o nounset -o pipefail

cd "$(dirname "$0")/.."
miniforge="$(grep -m1 -o 'condaforge/miniforge3:[0-9A-Za-z._-]*' test/Dockerfile)"

docker run --rm -i --platform linux/amd64 "$miniforge" bash -c '
  set -o errexit
  cat > /tmp/environment.yml
  conda env create --quiet --prefix /tmp/env --file /tmp/environment.yml > /dev/null
  echo "# environment.yml md5: $(md5sum /tmp/environment.yml | cut -d " " -f 1)"
  conda list --prefix /tmp/env --explicit --md5
' < python/environment.yml > python/conda-linux-64.lock.new
mv python/conda-linux-64.lock.new python/conda-linux-64.lock
