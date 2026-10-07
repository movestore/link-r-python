#!/bin/bash
# The python-born edge case: an empty TrajectoryCollection, as a python App may hand one on.
#   <cases>/empty_trajectory_collection/output.pickle
set -o errexit -o nounset

dir="$1/empty_trajectory_collection"
mkdir -p "$dir"

conda run --no-capture-output --prefix "$ENV_PREFIX" python -c '
import sys
import movingpandas as mpd
import pandas as pd
pd.to_pickle(mpd.TrajectoryCollection([]), sys.argv[1], compression="gzip")
' "$dir/output.pickle"
