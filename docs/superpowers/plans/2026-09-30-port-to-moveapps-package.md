# Port to the `moveapps` R package — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Both translator Apps build `FROM` the current R co-pilot and run on the `moveapps` package with output equal to `v2.2.0`, one `Dockerfile` builds both, and R side, python side and the CSV contract between them are tested in CI inside the real App images.

**Architecture:** The R logic moves from two top-level scripts into pure functions in `r/link.R`; the entry scripts shrink to SDK glue. Golden CSV pairs and round-trip expectations are produced **once by the v2.2.0 production images** and pinned in the repository; every later step proves itself by reproducing them (`git diff --exit-code`). CI builds the real `Dockerfile` on a public stand-in for the private co-pilot via `docker buildx bake`.

**Tech Stack:** R 4.6.1, renv 1.2.4, move2, sf, testthat 3.3.2, `moveapps` 1.0.3; python (conda-forge, pandas <3, geopandas, movingpandas), unittest; Docker BuildKit / buildx bake; GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-30-port-to-moveapps-package-design.md` — read it before any task. **The plan may be wrong.** Where a step's code or expectation contradicts what you measure, stop and report the measurement; do not bend the test or the code to make the plan true.

## Global Constraints

- Repository: `/opt/couchbits/projects/max-planck-gesellschaft/moveapps/apps/link-r-python/.claude/worktrees/port-to-moveapps-package`, branch `feature/port-to-moveapps-package` (no upstream on purpose). Every command below runs from this directory unless it says otherwise. Commit only here — never in the main checkout `/opt/…/apps/link-r-python`.
- **Never** push, open a pull request, tag, or create App versions without an explicit go from Clemens in chat. That is Task 14, and it waits.
- Code, comments, commit messages: English. Chat: German.
- New tests mark their blocks `# arrange` / `# act` / `# assert`. Existing tests keep their words (`# prepare` / `# execute` / `# verify`), also where this plan edits them.
- R: camelCase names like the SDK (`linkMeta`, `readLink`); call functions with named arguments where the original code did or where you write new calls.
- Commit messages: subject ≤ 50 chars, imperative, capitalised, no period; blank line; body wrapped at 72, explains what and why; last line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No "Generated with" line anywhere.
- Images (exact):
  - R co-pilot: `registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-r:v4.0.0_sdk-v1.0.3_geospatial-4.6.1_4674`
  - python co-pilot (conda source): `registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v1-python:v3.1.0`
  - rocker for the stand-in: `rocker/geospatial@sha256:4cee92a576e26c31546860eb252290f8f259e8236d49600d6bee695dfb96cae5` (tag `4.6.1`)
  - Miniforge for CI: `condaforge/miniforge3:26.7.2-0`
  - v2.2.0 production, R → python: `gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-a81e3046-bc48-4fcb-8d28-4291000c77f9-move2loc-to-movingpandas:7`
  - v2.2.0 production, python → R: `gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-ed490356-9d55-4cb3-90d1-b8a2fc18ce10-movingpandas-to-move2loc:6`
- Template test data: `movestore/Template_R_Function_App` at `e00af0d779f9756c40161bffd8d6f0a5ebc77ced`; local clone at `/opt/couchbits/projects/max-planck-gesellschaft/moveapps/apps/Template_R_Function_App`.
- Apple Silicon: all App images are `linux/amd64` and run emulated. Pass `--platform linux/amd64` where a command below does. **Never** set `DOCKER_DEFAULT_PLATFORM`.
- Docker Desktop cannot bind-mount the macOS temp directories (`/private/tmp/…`). The scripts below copy in and out with `docker create` / `docker cp` / `docker start --attach` instead of `-v`.
- A long build (> 2 min) runs in the background; confirm its end by its output (`naming to …`, `exporting`, or an `ERROR` line), never by a notification alone.
- Subagents: do the work yourself; do not dispatch further agents.

## File Structure

| Path | Responsibility | Task |
|---|---|---|
| `r/data/raw/*.rds`, `r/data/raw/README.txt` | sample inputs: Template set + the List file | 1 |
| `test/images.sh` | host helper: run a command in an App image, copy results out | 2 |
| `test/roundtrip/r2python.sh`, `test/roundtrip/python2r.sh` | run every case through one entry point, record exit codes | 2 |
| `test/roundtrip/synthetic.R` | derive the two non-UTC cases from input1 | 2 |
| `test/roundtrip/empty.sh` | write the python-born empty case | 2 |
| `test/roundtrip/stage-r2python.sh`, `test/roundtrip/stage-python2r.sh` | one round-trip half inside one image | 2 |
| `test/roundtrip/describe.R` | describe a round trip; as a script, pin it | 2 |
| `test/roundtrip/measure.sh` | host: measure two images, write the pins | 2 |
| `test/roundtrip/expected.csv`, `test/roundtrip/classes.csv` | the pins | 2, 7–11 |
| `test/contract/cut.R`, `test/contract/prepare.sh`, `test/contract/generate.sh` | cut the contract cases, produce the golden CSV pairs | 2 |
| `test/contract/<case>/{input.rds,meta.csv,link.csv,py/meta.csv,py/link.csv}` | the goldens, 6 cases | 2, 8 |
| `python/tests/test_contract.py` | python half of the contract | 3 |
| `python/tests/test_transform_to_{csv,pickle}.py` | python unit gaps, later the fixes | 3, 7, 8, 10 |
| `r/link.R` | the R logic: `linkMeta`, `linkTable`, `writeLink`, `readLink` | 4, 7–9, 11 |
| `r/rds_2_csv.R`, `r/csv_2_rds.R` | entry points: SDK glue only | 4, 5, 7 |
| `r/.renvignore` | keep `tests/` out of the App's lock | 4 |
| `r/tests/testthat/*.R` | R unit and contract tests | 4, 7–9, 11 |
| `r/renv.lock`, `r/renv/activate.R` | R 4.6.1 lock | 5 |
| `r/src/**` | deleted | 5 |
| `Dockerfile`, `r2python.sh`, `python2r.sh` | App build and entry, both directions | 5 |
| `test/Dockerfile` | python unit tests; Miniforge bump | 3, 5 |
| `test/co-pilot-r.Dockerfile` | public stand-in for the R co-pilot | 6 |
| `test/docker-bake.hcl` | build graph for CI and local runs | 6 |
| `test/app-test.Dockerfile` | R unit tests, round trip, coherence inside the App images | 6 |
| `test/roundtrip/run.sh`, `test/roundtrip/compare.R` | in-image round trip and its check | 6 |
| `test/coherence.R` | cross-file version pins agree | 6 |
| `.dockerignore`, `.github/workflows/test.yml` | build context, CI job `app` | 6 |
| `README.md` | build and test instructions, behaviour | 12 |

---

### Task 1: Replace the sample inputs with the Template set

**Files:**
- Delete: `r/data/raw/input{1,2,3,4}_move2loc_{LatLon,Mollweide}.rds` (8 files)
- Create: the 8 files of the same names from the Template commit
- Modify: `r/data/raw/README.txt`
- Keep: `r/data/raw/input_move2loc_List.rds`

**Interfaces:**
- Produces: `r/data/raw/input1_move2loc_LatLon.rds` … `input4_move2loc_Mollweide.rds` (current Movebank cut), `r/data/raw/input_move2loc_List.rds` (unchanged). Later tasks read `r/data/raw/*move2loc*.rds`.

- [ ] **Step 1: Replace the files**

```bash
TEMPLATE=/opt/couchbits/projects/max-planck-gesellschaft/moveapps/apps/Template_R_Function_App
SHA=e00af0d779f9756c40161bffd8d6f0a5ebc77ced
for f in $(git -C "$TEMPLATE" ls-tree --name-only "$SHA" data/raw/ | grep move2loc); do
  git -C "$TEMPLATE" show "$SHA:$f" > "r/data/raw/$(basename "$f")"
done
```

- [ ] **Step 2: Verify they are the Template's blobs, byte for byte**

```bash
for f in $(git -C "$TEMPLATE" ls-tree --name-only "$SHA" data/raw/ | grep move2loc); do
  test "$(git hash-object "r/data/raw/$(basename "$f")")" = "$(git -C "$TEMPLATE" rev-parse "$SHA:$f")" && echo "ok $f" || echo "MISMATCH $f"
done
```
Expected: 8 lines `ok data/raw/…`, no `MISMATCH`. `git status --short r/data/raw` shows 8 `M` lines and nothing else.

- [ ] **Step 3: Rewrite `r/data/raw/README.txt`**

```text
Set of input data to test apps.

Source: github.com/movestore/Template_R_Function_App, data/raw at commit
e00af0d779f9756c40161bffd8d6f0a5ebc77ced (2026-09-28), the move2_loc files only - the
telemetry.list files are no input type of the translators.
input_move2loc_List.rds is this repository's own: the only input with list columns in its
track data.

*Content*
- input1: 1 goat, median fix rate = 30mins, tracking duration 7.5 month, gps, local movement
- input2: 3 storks, median fix rate = 1sec, tracking duration 2 weeks, gps, local movement
- input3: 1 stork, one track per deployment, median fix rate = 1h | 1day | 1 week, tracking duration 11.5 years, argos, includes migration
- input4: 3 geese, median fix rate = 1h | 4h, tracking duration 1.5 years, gps, includes migration
- input_move2loc_List: 5 locations in 4 tracks, three of them with a single fix

*Projection*
- data are provided in "lat/long" (EPSG:4326) and projected to "Mollweide" (ESRI:54009) in order to test your app accordingly for not projected and projected data.

*File names*
input1_move2loc_LatLon.rds
input1_move2loc_Mollweide.rds

input2_move2loc_LatLon.rds
input2_move2loc_Mollweide.rds

input3_move2loc_LatLon.rds
input3_move2loc_Mollweide.rds

input4_move2loc_LatLon.rds
input4_move2loc_Mollweide.rds

input_move2loc_List.rds
```

- [ ] **Step 4: Commit**

```bash
git add r/data/raw/
git commit -F - <<'EOF'
Use the current Template sample data

The eight move2_loc inputs came from an older cut of the Template's
data: same observations, but more event columns and another track id
column than Movebank delivers today. Taken byte for byte from
Template_R_Function_App e00af0d. The List file stays, it is the only
input with list columns.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 2: Pin v2.2.0 — goldens and round-trip expectations from the production images

The production images are the reference. Everything here is tooling plus the files it writes; the tooling is reused unchanged by Tasks 4, 5 and 7–11 and by CI.

**Files:**
- Create: `test/images.sh`, `test/roundtrip/{r2python.sh,python2r.sh,synthetic.R,empty.sh,stage-r2python.sh,stage-python2r.sh,describe.R,measure.sh}`, `test/contract/{cut.R,prepare.sh,generate.sh}`
- Create (generated): `test/roundtrip/expected.csv`, `test/roundtrip/classes.csv`, `test/contract/<case>/{input.rds,meta.csv,link.csv,py/meta.csv,py/link.csv}` for the six cases

**Interfaces:**
- Produces:
  - `runInImage <image> <input dir> <command> <output dir>` (bash function in `test/images.sh`); env `OVERLAY=1` copies this checkout's `r/link.R r/rds_2_csv.R r/csv_2_rds.R` into the image first.
  - `test/roundtrip/r2python.sh <start script> <inputs dir> <cases dir>` → `<cases>/<case>/{input.rds,output.pickle,meta.csv,link.csv,r2python.exit,r2python.log}`
  - `test/roundtrip/python2r.sh <start script> <cases dir>` → `<case>/{output.rds,py/meta.csv,py/link.csv,python2r.exit,python2r.log}` for each case holding `output.pickle`
  - `test/roundtrip/stage-r2python.sh <raw dir> <out dir>`, `test/roundtrip/stage-python2r.sh <cases dir> <out dir>` (env `START`, default `./start-process.sh`)
  - `test/roundtrip/describe.R`: `describeCase(dir)`, `describeAll(cases)`, `writeDescription(described, expectedFile, classesFile)`; as a script `Rscript describe.R <cases> <expected.csv> <classes.csv>`
  - `test/roundtrip/measure.sh`, `test/contract/generate.sh` — env `R2PY_IMAGE`, `PY2R_IMAGE` (default: v2.2.0 production), `OVERLAY`, `KEEP=<dir>` (measure only), `CUT=1` (generate only)
  - Case names: `latlon-three-tracks`, `mollweide-midnight`, `subsecond`, `argos-sfc`, `list-columns`, `berlin`; round-trip cases additionally `input1_move2loc_LatLon_berlin`, `dst_ambiguous`, `empty_trajectory_collection`.

- [ ] **Step 1: Pull the production images**

```bash
docker pull --platform linux/amd64 gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-a81e3046-bc48-4fcb-8d28-4291000c77f9-move2loc-to-movingpandas:7
docker pull --platform linux/amd64 gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-ed490356-9d55-4cb3-90d1-b8a2fc18ce10-movingpandas-to-move2loc:6
```
Expected: both end with the image name. A `denied` means registry login — stop and ask Clemens.

- [ ] **Step 2: Write `test/images.sh`**

```bash
# Runs a command inside an App image and copies its results out. No bind mounts: Docker Desktop on
# macOS cannot mount the per-user temp directories, and copying leaves the image's own files alone.
#
#   runInImage <image> <input dir> <command> <output dir>
#     <input dir>  -> /tmp/in   read only: owned by root inside the container
#     <command>       runs as the image's user in /home/moveapps/co-pilot-r and writes to /tmp/out
#     /tmp/out     -> <output dir>
#
# OVERLAY=1 first replaces the image's r/link.R, r/rds_2_csv.R and r/csv_2_rds.R with this
# checkout's - how a change to the R side is proved against an older image.
runInImage() {
  local image="$1" input="$2" command="$3" output="$4"
  local container status

  container="$(docker create --platform linux/amd64 --entrypoint bash -w /home/moveapps/co-pilot-r "$image" -c "$command")"
  docker cp "$input" "$container:/tmp/in" > /dev/null

  if [ "${OVERLAY:-0}" = 1 ]; then
    for file in r/link.R r/rds_2_csv.R r/csv_2_rds.R; do
      docker cp "$file" "$container:/home/moveapps/co-pilot-r/$file" > /dev/null
    done
  fi

  docker start --attach "$container" && status=0 || status=$?

  rm -rf "$output"
  docker cp "$container:/tmp/out" "$output" > /dev/null || true
  docker rm "$container" > /dev/null
  return "$status"
}
```

- [ ] **Step 3: Write the per-entry-point runners**

`test/roundtrip/r2python.sh`:
```bash
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
```

`test/roundtrip/python2r.sh`:
```bash
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
```

- [ ] **Step 4: Write the case generators**

`test/roundtrip/synthetic.R`:
```r
# Derives the non-UTC round-trip cases from input1. Movebank data are UTC; these are the edge cases.
#   input1_move2loc_LatLon_berlin.rds - all of input1, displayed in Europe/Berlin
#   dst_ambiguous.rds                 - two fixes at 00:30 and 01:30 UTC on 2021-10-31, both 02:30 local
#   Rscript synthetic.R <input1.rds> <out dir>
suppressMessages(library("move2"))

args <- commandArgs(trailingOnly = TRUE)
input1 <- readRDS(args[1])

berlin <- input1
attr(berlin[[mt_time_column(berlin)]], "tzone") <- "Europe/Berlin"
saveRDS(berlin, file.path(args[2], "input1_move2loc_LatLon_berlin.rds"))

ambiguous <- input1[1:2, ]
ambiguous[[mt_time_column(ambiguous)]] <- as.POSIXct(c("2021-10-31 00:30:00", "2021-10-31 01:30:00"), tz = "UTC")
attr(ambiguous[[mt_time_column(ambiguous)]], "tzone") <- "Europe/Berlin"
saveRDS(ambiguous, file.path(args[2], "dst_ambiguous.rds"))
```

`test/roundtrip/empty.sh`:
```bash
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
```

- [ ] **Step 5: Write the two stages**

`test/roundtrip/stage-r2python.sh`:
```bash
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
```

`test/roundtrip/stage-python2r.sh`:
```bash
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
```

`chmod +x test/roundtrip/*.sh`.

- [ ] **Step 6: Write `test/roundtrip/describe.R`**

```r
# Describes what the round trip R -> python -> R did to every case directory in <cases>:
#   <case>/input.rds       what went in (absent for a python-born case)
#   <case>/r2python.exit   exit code of the R -> python App; <case>/r2python.log its log
#   <case>/python2r.exit   exit code of the python -> R App
#   <case>/output.rds      what came back (absent if an App failed, empty for the NULL result)
#
# Sourced by compare.R. Run as a script it pins the description:
#   Rscript describe.R <cases> <expected.csv> <classes.csv>

suppressMessages({
  library("move2")
  library("sf")
})

readExit <- function(file) {
  if (file.exists(file)) as.integer(readLines(file, n = 1)) else NA_integer_
}

classOf <- function(x) paste(class(x), collapse = "/")

# the input rows of the tracks the output kept, and the output, both ordered by track id and time;
# radix ordering is locale-free, so two images with different locales order alike
alignRows <- function(input, output) {
  input <- input[as.character(mt_track_id(input)) %in% as.character(mt_track_id(output)), ]
  list(
    input = input[order(as.character(mt_track_id(input)), as.numeric(mt_time(input)), method = "radix"), ],
    output = output[order(as.character(mt_track_id(output)), as.numeric(mt_time(output)), method = "radix"), ]
  )
}

describeCase <- function(dir) {
  case <- basename(dir)
  log <- file.path(dir, "r2python.log")
  summary <- data.frame(
    case = case,
    r2python_exit = readExit(file.path(dir, "r2python.exit")),
    python2r_exit = readExit(file.path(dir, "python2r.exit")),
    rows_out = NA_integer_,
    tracks_out = NA_integer_,
    max_time_deviation_s = NA_character_,
    time_column_out = NA_character_,
    tzone_out = NA_character_,
    dropped_tracks_warned = if (file.exists(log)) sum(grepl("^\\[WARN\\] track ", readLines(log, warn = FALSE))) else NA_integer_
  )
  described <- list(summary = summary, classes = NULL, aligned = NULL)

  outputFile <- file.path(dir, "output.rds")
  if (!file.exists(outputFile)) {
    return(described)
  }
  if (file.size(outputFile) == 0) {
    described$summary$rows_out <- 0L
    return(described)
  }

  output <- readRDS(outputFile)
  described$summary$rows_out <- nrow(output)
  described$summary$tracks_out <- mt_n_tracks(output)
  described$summary$time_column_out <- mt_time_column(output)
  described$summary$tzone_out <- attr(mt_time(output), "tzone")

  inputFile <- file.path(dir, "input.rds")
  if (!file.exists(inputFile)) {
    return(described)
  }
  input <- readRDS(inputFile)
  aligned <- alignRows(input = input, output = output)
  if (nrow(aligned$input) == nrow(aligned$output) && nrow(aligned$output) > 0) {
    deviation <- abs(as.numeric(mt_time(aligned$input)) - as.numeric(mt_time(aligned$output)))
    described$summary$max_time_deviation_s <- sprintf("%.3f", max(deviation))
  }

  # the input as it travels: track attributes become event attributes on the way out
  events <- mt_as_event_attribute(input, names(mt_track_data(input)))
  namesIn <- setdiff(names(events), attr(events, "sf_column"))
  namesOut <- setdiff(names(output), attr(output, "sf_column"))
  columns <- union(namesIn, namesOut)
  described$classes <- data.frame(
    case = case,
    column = columns,
    class_in = vapply(columns, function(column) if (column %in% namesIn) classOf(events[[column]]) else NA_character_, character(1)),
    class_out = vapply(columns, function(column) if (column %in% namesOut) classOf(output[[column]]) else NA_character_, character(1)),
    row.names = NULL
  )

  described$aligned <- aligned
  described$input <- input
  described$output <- output
  described$namesIn <- namesIn
  described$namesOut <- namesOut
  described
}

describeAll <- function(cases) {
  lapply(sort(list.dirs(cases, recursive = FALSE), method = "radix"), describeCase)
}

# one CSV line per case, and one per case and column
writeDescription <- function(described, expectedFile, classesFile) {
  write.csv(do.call(rbind, lapply(described, `[[`, "summary")), expectedFile, row.names = FALSE, na = "")
  write.csv(do.call(rbind, lapply(described, `[[`, "classes")), classesFile, row.names = FALSE, na = "")
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  writeDescription(described = describeAll(cases = args[1]), expectedFile = args[2], classesFile = args[3])
}
```

- [ ] **Step 7: Write `test/roundtrip/measure.sh`**

```bash
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
```

- [ ] **Step 8: Write the contract generator**

`test/contract/cut.R`:
```r
# Cuts the contract cases out of the sample inputs: a few rows each, by row number of the full input.
#   Rscript cut.R <raw dir> <contract dir>
suppressMessages(library("move2"))

cases <- list(
  "latlon-three-tracks" = list(file = "input4_move2loc_LatLon.rds", rows = c(1:4, 3011:3014, 4506:4509)),
  "mollweide-midnight" = list(file = "input1_move2loc_Mollweide.rds", rows = 2728:2731),
  "subsecond" = list(file = "input2_move2loc_LatLon.rds", rows = 3443:3446),
  "argos-sfc" = list(file = "input3_move2loc_LatLon.rds", rows = c(1, 2, 25, 26, 63, 64, 365, 366, 938, 939)),
  "list-columns" = list(file = "input_move2loc_List.rds", rows = 1:5),
  "berlin" = list(file = "input1_move2loc_LatLon.rds", rows = 1:4, tzone = "Europe/Berlin")
)

args <- commandArgs(trailingOnly = TRUE)
for (name in names(cases)) {
  spec <- cases[[name]]
  data <- readRDS(file.path(args[1], spec$file))[spec$rows, ]
  if (!is.null(spec$tzone)) {
    attr(data[[mt_time_column(data)]], "tzone") <- spec$tzone
  }
  dir.create(file.path(args[2], name), recursive = TRUE, showWarnings = FALSE)
  saveRDS(data, file.path(args[2], name, "input.rds"))
}
```

`test/contract/prepare.sh`:
```bash
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
```

`test/contract/generate.sh`:
```bash
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
```

`chmod +x test/contract/*.sh`.

- [ ] **Step 9: Produce the goldens and the pins**

```bash
CUT=1 test/contract/generate.sh
test/roundtrip/measure.sh
```
Both take a few minutes each (emulated). Expected: exit 0; `ls test/contract` shows the six case directories, each with `input.rds meta.csv link.csv py/`.

- [ ] **Step 10: Check the pins against the measurement taken while planning**

```bash
cat test/roundtrip/expected.csv
grep -c '' test/contract/list-columns/py/link.csv
grep -o '"2021-07-01 0[0-9]:40:00.000"' test/contract/berlin/link.csv | head -1
```
Expected, from the spec's "round trip of v2.2.0, measured":
- every `r/data/raw` case: `r2python_exit` 0, `python2r_exit` 0, `time_column_out` `timestamp_utc`, `tzone_out` `UTC`, `dropped_tracks_warned` 0;
- `input2_move2loc_LatLon` and `input2_move2loc_Mollweide`: `max_time_deviation_s` `0.999`; every other case with an output `0.000`;
- `input_move2loc_List`: `rows_out` 2, `tracks_out` 1;
- `dst_ambiguous`: `r2python_exit` 1, no `python2r_exit`, no rows;
- `empty_trajectory_collection`: empty `r2python_exit`, `python2r_exit` 1;
- `list-columns/py/link.csv`: 3 lines (header + 2);
- berlin: `"2021-07-01 08:40:00.000"` (Berlin wall-clock time).

Any other value: stop and report it — the pins must describe production, not this plan.

- [ ] **Step 11: Prove the tooling deterministic**

```bash
git add test/
test/contract/generate.sh && test/roundtrip/measure.sh
git diff --exit-code test/
```
Expected: exit 0 — the second run writes the very bytes of the first.

- [ ] **Step 12: Commit**

```bash
git add test/
git commit -F - <<'EOF'
Pin v2.2.0: golden CSV pairs and round-trip data

The v2.2.0 production images, pulled from the platform registry,
produced every golden and every expectation here - so what later
steps must reproduce is literally what runs in production. The
scripts that did it are committed alongside and are reused to prove
the refactoring, the port and each fix.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 3: Python — close the unit gaps, pin the contract

**Files:**
- Create: `python/tests/test_contract.py`
- Modify: `python/tests/test_transform_to_csv.py`, `python/tests/test_transform_to_pickle.py`, `test/Dockerfile`

**Interfaces:**
- Consumes: `test/contract/<case>/{meta.csv,link.csv,py/meta.csv,py/link.csv}` (Task 2).
- Produces: test module `python.tests.test_contract`, listed in `test/Dockerfile`.

- [ ] **Step 1: Write `python/tests/test_contract.py`**

```python
import os
import tempfile
import unittest

from ..transform_to_csv import TransformToCsv
from ..transform_to_pickle import TransformToPickle

CONTRACT_DIR = './test/contract'


class ContractTestCase(unittest.TestCase):
    """
    The CSV pair between R and python, pinned by golden files the v2.2.0 production images produced:
    R's link.csv and meta.csv go in, and what python hands back to R must equal py/link.csv and
    py/meta.csv byte for byte.
    """

    def test_it_should_hand_back_the_python_csv_pair_of_every_case(self):
        cases = sorted(case for case in os.listdir(CONTRACT_DIR) if os.path.isdir(os.path.join(CONTRACT_DIR, case)))
        self.assertEqual(6, len(cases))

        for case in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as tmp:
                # arrange
                case_dir = os.path.join(CONTRACT_DIR, case)
                pickle = os.path.join(tmp, 'output_file')
                link = os.path.join(tmp, 'link.csv')
                meta = os.path.join(tmp, 'meta.csv')
                TransformToPickle().convert(
                    input_data_file_name=os.path.join(case_dir, 'link.csv'),
                    input_meta_file_name=os.path.join(case_dir, 'meta.csv'),
                    output_file_name=pickle
                )

                # act
                TransformToCsv().convert(input_data_file_name=pickle, output_file_name=link, output_meta_file_name=meta)

                # assert
                self.assertEqual(self.__read(os.path.join(case_dir, 'py', 'meta.csv')), self.__read(meta))
                self.assertEqual(self.__read(os.path.join(case_dir, 'py', 'link.csv')), self.__read(link))

    @staticmethod
    def __read(file_path) -> bytes:
        with open(file_path, 'rb') as file:
            return file.read()
```

- [ ] **Step 2: Register it in `test/Dockerfile`**

Add after `COPY python/ ./python/`:
```dockerfile
# the golden CSV pairs the contract test reads, shared with the R tests
COPY test/contract/ ./test/contract/
```
and extend the test command's module list:
```dockerfile
RUN conda run --no-capture-output --prefix ${ENV_PREFIX} python -m unittest \
    python.tests.test_transform_to_pickle python.tests.test_transform_to_csv python.tests.test_contract
```

- [ ] **Step 3: Add the unit gaps to `python/tests/test_transform_to_pickle.py`**

Change the import to `from ..transform_to_pickle import Meta, TransformToPickle` and add to `TransformToPickleTestCase`:
```python
    def test_it_should_read_the_meta_csv(self):
        # arrange
        file_path = './python/sample/input4/meta.csv'

        # act
        actual = self.sut.read_meta_csv(file_path=file_path)

        # assert
        self.assertEqual(
            Meta(projection='EPSG:4326', timezone='UTC', time_col_name='timestamp', track_id_col_name='individual_name_deployment_id'),
            actual
        )

    def test_it_should_create_one_trajectory_per_track_in_the_crs_of_the_meta_csv(self):
        # arrange
        meta = self.sut.read_meta_csv(file_path='./python/sample/input4/meta.csv')
        data = self.sut.read_data_csv(file_path='./python/sample/input4/link.csv', time_col_name=meta.time_col_name)
        self.sut.adjust_timestamps(data=data, timezone=meta.timezone, time_col_name=meta.time_col_name)

        # act
        actual = self.sut.create_moving_pandas(data=data, projection=meta.projection, track_id_col_name=meta.track_id_col_name)

        # assert: the sample carries three distinct tracks
        self.assertEqual(3, len(actual.trajectories))
        self.assertEqual('EPSG:4326', actual.trajectories[0].df.crs.to_string())
```

- [ ] **Step 4: Add the unit gaps to `python/tests/test_transform_to_csv.py`**

```python
    def test_it_should_write_crs_timezone_and_column_names_to_the_meta_csv(self):
        # arrange
        data = self.sut.read_data_pickle(file_path=self.compressed)
        geopandas = self.sut.create_geopandas(data=data)
        meta = os.path.join(self.tmp.name, 'meta.csv')

        # act
        self.sut.write_meta_csv(geopanda=geopandas, movingpanda=data, file_path=meta)

        # assert: the time column is the index movingpandas built from `timestamp_utc`
        with open(meta) as written:
            actual = written.read().splitlines()
        self.assertEqual(
            ['crs,tzone,timeColName,trackIdColName', 'EPSG:4326,UTC,timestamp_utc,individual_name_deployment_id'],
            actual
        )

    def test_it_should_write_the_time_index_and_the_coordinates_to_the_link_csv(self):
        # arrange
        data = self.sut.read_data_pickle(file_path=self.compressed)
        geopandas = self.sut.create_geopandas(data=data)
        link = os.path.join(self.tmp.name, 'link.csv')

        # act
        self.sut.write_result(file_name=link, data=geopandas)

        # assert
        with open(link) as written:
            actual = written.readline().rstrip('\n').split(',')
        self.assertEqual('timestamp_utc', actual[0])
        self.assertIn('coords_x', actual)
        self.assertIn('coords_y', actual)
```

- [ ] **Step 5: Run the python suite**

Run: `docker build -f test/Dockerfile -t link-r-python-python-tests . 2>&1 | tail -20`
Expected: `Ran 15 tests` and `OK` (10 existing + 2 + 2 + 1).

If `test_contract` fails, **do not regenerate the goldens.** Diff the two files the assertion names (`cmp` then `diff`) and report the difference: the test environment resolves conda afresh, the goldens came from the production images, and a difference is a real contract drift that Clemens decides on.

- [ ] **Step 6: Mutate once**

Change one character in `test/contract/subsecond/py/link.csv`, rerun Step 5: `test_contract` must fail naming `subsecond`. Revert with `git checkout -- test/contract/subsecond/py/link.csv`.

- [ ] **Step 7: Commit**

```bash
git add python/tests/ test/Dockerfile
git commit -F - <<'EOF'
Test the python half of the CSV contract

The goldens from v2.2.0 now bind python: R's CSV pair goes in, and
what python hands back must match production byte for byte. Adds the
first tests of the meta.csv and link.csv python writes, and of reading
meta.csv and building the collection.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 4: R — extract `r/link.R`, test it, prove the refactoring on v2.2.0

**Files:**
- Create: `r/link.R`, `r/.renvignore`, `r/tests/testthat/helper-link.R`, `r/tests/testthat/test-link-meta.R`, `r/tests/testthat/test-link-table.R`, `r/tests/testthat/test-read-link.R`, `r/tests/testthat/test-contract.R`
- Modify: `r/rds_2_csv.R`, `r/csv_2_rds.R` (they still `source()` the old SDK — the port is Task 5)

**Interfaces:**
- Consumes: goldens and pins (Task 2), `OVERLAY=1` of `test/images.sh`.
- Produces (R, in `r/link.R`):
  - `linkMeta(data)` → data.frame(crs, tzone, timeColName, trackIdColName)
  - `linkTable(data)` → data.frame, the rows of `link.csv`
  - `writeLink(data, bufferFile, metaFile)` → writes `metaFile`, then `bufferFile`
  - `readLink(bufferFile, metaFile)` → move2, or `NULL` for a buffer without rows

- [ ] **Step 1: Write the tests first**

`r/tests/testthat/helper-link.R`:
```r
# the code under test, and the contract cases shared with the python tests
source(file.path("..", "..", "link.R"))

contractDir <- file.path("..", "..", "..", "test", "contract")
contractCases <- basename(list.dirs(contractDir, recursive = FALSE))

readCase <- function(case) readRDS(file.path(contractDir, case, "input.rds"))

writeTempLines <- function(lines) {
  file <- tempfile(fileext = ".csv")
  writeLines(lines, file)
  file
}

metaFileFor <- function(tzone = "UTC") {
  writeTempLines(c(
    "crs,tzone,timeColName,trackIdColName",
    sprintf("EPSG:4326,%s,timestamp_utc,track", tzone)
  ))
}
```

`r/tests/testthat/test-link-meta.R`:
```r
test_that("linkMeta names crs, tzone, time and track column", {
  # arrange
  data <- readCase("latlon-three-tracks")

  # act
  actual <- linkMeta(data = data)

  # assert
  expect_equal(actual, data.frame(crs = "EPSG:4326", tzone = "UTC", timeColName = "timestamp", trackIdColName = "individual_local_identifier"))
})

test_that("linkMeta keeps the crs of a projected input", {
  # arrange
  data <- readCase("mollweide-midnight")

  # act
  actual <- linkMeta(data = data)

  # assert
  expect_equal(actual$crs, "ESRI:54009")
})

test_that("linkMeta keeps a timezone other than UTC", {
  # arrange
  data <- readCase("berlin")

  # act
  actual <- linkMeta(data = data)

  # assert
  expect_equal(actual$tzone, "Europe/Berlin")
})
```

`r/tests/testthat/test-link-table.R`:
```r
test_that("linkTable carries one row per location with its coordinates, without geometry", {
  # arrange
  data <- readCase("latlon-three-tracks")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_equal(nrow(actual), 12)
  expect_equal(actual$coords_x, unname(sf::st_coordinates(data)[, 1]))
  expect_equal(actual$coords_y, unname(sf::st_coordinates(data)[, 2]))
  expect_false("geometry" %in% names(actual))
})

test_that("linkTable repeats the track attributes on every row", {
  # arrange
  data <- readCase("latlon-three-tracks")

  # act
  actual <- linkTable(data = data)

  # assert: data.frame() makes the names syntactic, as v2.2.0 did
  expect_true(all(make.names(names(mt_track_data(data))) %in% names(actual)))
})

test_that("linkTable writes sfc attributes as WKT", {
  # arrange
  data <- readCase("argos-sfc")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_type(actual$argos_location_1, "character")
  expect_match(actual$argos_location_1, "^POINT \\(")
})

test_that("linkTable leaves no list column behind", {
  # arrange
  data <- readCase("list-columns")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_false(any(vapply(actual, is.list, logical(1))))
})

test_that("linkTable keeps the milliseconds of a midnight fix", {
  # arrange
  data <- readCase("mollweide-midnight")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_true("2021-12-10 00:00:00.000" %in% actual$timestamp)
})

test_that("linkTable keeps milliseconds below the second", {
  # arrange
  data <- readCase("subsecond")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_equal(actual$timestamp, c("2014-08-06 09:19:35.000", "2014-08-06 09:19:35.999", "2014-08-06 09:19:36.999", "2014-08-06 09:19:38.000"))
})
```

`r/tests/testthat/test-read-link.R`:
```r
test_that("readLink returns NULL for a buffer without rows", {
  # arrange
  buffer <- writeTempLines("timestamp_utc,track,coords_x,coords_y")

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_null(actual)
})

test_that("readLink builds a move2 in the crs of meta.csv, ordered by track and time", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y",
    "2021-07-01 06:46:00,b,1,2",
    "2021-07-01 06:40:00,b,3,4",
    "2021-07-01 06:40:00,a,5,6"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_true(mt_is_move2(actual))
  expect_equal(sf::st_crs(actual), sf::st_crs("EPSG:4326"))
  expect_equal(as.character(mt_track_id(actual)), c("a", "b", "b"))
  expect_equal(format(mt_time(actual), "%H:%M"), c("06:40", "06:40", "06:46"))
})

test_that("readLink reads the times in the tzone of meta.csv", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y",
    "2021-07-01 06:40:00,a,1,2",
    "2021-07-01 06:46:00,a,1,2"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor(tzone = "Asia/Kolkata"))

  # assert: 06:40 in Kolkata (UTC+05:30) is 01:10 UTC
  expect_equal(attr(mt_time(actual), "tzone"), "Asia/Kolkata")
  expect_equal(format(mt_time(actual)[1], "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2021-07-01 01:10:00")
})

test_that("readLink truncates sub-second times (v2.2.0, pinned)", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y",
    "2021-07-01 06:40:00.123,a,1,2",
    "2021-07-01 06:40:01.000,a,1,2"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_equal(as.numeric(mt_time(actual))[1] %% 1, 0)
})

test_that("readLink leaves python's True and False as text (v2.2.0, pinned)", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y,visible",
    "2021-07-01 06:40:00,a,1,2,True",
    "2021-07-01 06:46:00,a,1,2,False"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_equal(actual$visible, c("True", "False"))
})
```

`r/tests/testthat/test-contract.R`:
```r
# the CSV pair between R and python, pinned by the goldens the v2.2.0 production images produced
bytesOf <- function(file) readBin(file, what = "raw", n = file.size(file))

for (case in contractCases) {
  test_that(sprintf("writeLink reproduces the v2.2.0 CSV pair of '%s' byte for byte", case), {
    # arrange
    buffer <- tempfile(fileext = ".csv")
    meta <- tempfile(fileext = ".csv")

    # act
    writeLink(data = readCase(case), bufferFile = buffer, metaFile = meta)

    # assert
    expect_identical(bytesOf(meta), bytesOf(file.path(contractDir, case, "meta.csv")))
    expect_identical(bytesOf(buffer), bytesOf(file.path(contractDir, case, "link.csv")))
  })

  test_that(sprintf("readLink turns python's CSV pair of '%s' back into its locations", case), {
    # arrange: python keeps only the tracks with at least two fixes
    input <- readCase(case)

    # act
    actual <- readLink(bufferFile = file.path(contractDir, case, "py", "link.csv"), metaFile = file.path(contractDir, case, "py", "meta.csv"))

    # assert: v2.2.0 truncates sub-second times
    kept <- input[as.character(mt_track_id(input)) %in% as.character(mt_track_id(actual)), ]
    expect_equal(nrow(actual), nrow(kept))
    expect_equal(sf::st_crs(actual), sf::st_crs(input))
    expect_equal(sort(as.numeric(mt_time(actual))), floor(sort(as.numeric(mt_time(kept)))))
  })
}
```

- [ ] **Step 2: Run them — they must fail**

Dev loop, native and fast; `--no-init-file` keeps the old renv project out:
```bash
COPYFILE_DISABLE=1 tar --no-xattrs -cf - r/tests test/contract | docker run --rm -i rocker/geospatial:4.6.1 bash -c '
  mkdir /w && tar -C /w -xf - && cd /w/r &&
  R -q -s -e "install.packages(c(\"move2\", \"testthat\"), quiet = TRUE)" > /dev/null 2>&1 &&
  Rscript --no-init-file -e "testthat::test_dir(\"tests/testthat\")"' 2>&1 | tail -15
```
Expected: FAIL at `helper-link.R` — `cannot open file '../../link.R'`.

This dev loop runs on R 4.6.1 with the newest CRAN packages, not on either lock. It is for fast feedback only; the binding runs are Step 6 below (v2.2.0) and Tasks 5 and 6 (the new lock).

- [ ] **Step 3: Write `r/link.R`** — the v2.2.0 logic moved, not changed

```r
# Converts between a move2 object and the CSV pair python reads and writes:
#
#   move2 --writeLink()--> meta.csv + link.csv --(python)--> pickle
#   pickle --(python)--> meta.csv + link.csv --readLink()--> move2
#
# meta.csv carries what a plain CSV cannot: crs, tzone, and which columns hold time and track id.

library("move2")
library("sf")
library("dplyr")
library("vctrs")
library("purrr")
library("rlang")

# meta.csv: one row with what link.csv cannot say itself
linkMeta <- function(data) {
  prj <- st_crs(data)[[1]]
  tz <- attr(mt_time(data),'tzone')
  data.frame(crs=c(prj), tzone=c(tz), timeColName=mt_time_column(data), trackIdColName=mt_track_id_column(data))
}

# link.csv: one row per location, the track attributes repeated on every row, geometry as coordinates
linkTable <- function(data) {
  ## checking if there are columns in the track data that are a list. If yes, check if the content is the same, if yes remove list. If list columns are left over because content is different transform these into a character string (could be done as well as json, but think that average user will be more comfortable with text?. Easy to change in the future. See Issue #78 on move2)
  if(any(sapply(mt_track_data(data), is_bare_list))){
    ## reduce all columns were entry is the same to one (so no list anymore)
    data <- data |> mutate_track_data(across(
      where( ~is_bare_list(.x) && all(purrr::map_lgl(.x, function(y) 1==length(unique(y)) ))),
      ~do.call(vctrs::vec_c,purrr::map(.x, head,1))))
    if(any(sapply(mt_track_data(data), is_bare_list))){
      ## transform those that are still a list into a character string
      data <- data |> mutate_track_data(across(
        where( ~is_bare_list(.x) && any(purrr::map_lgl(.x, function(y) 1!=length(unique(y)) ))),
        ~unlist(purrr::map(.x, paste, collapse=","))))
    }
  }
  data <- mt_as_event_attribute(data, names(mt_track_data(data)))
  data <- dplyr::mutate(data, coords_x=sf::st_coordinates(data)[,1],
                        coords_y=sf::st_coordinates(data)[,2])
  data <- sf::st_drop_geometry(data) ## removes the sf geometry column from the table
  sfc_cols <- names(data)[unlist(lapply(data, inherits, 'sfc'))] ## get the col names that are spacial

  for(x in sfc_cols){ ## converting the "point" columns into characters, ie into WKT (Well-known text)
    data[[x]] <- st_as_text(data[[x]])
  } ## st_as_sfc() can be used to convert these columns back to spacial

  data.csv <- data.frame(data)
  data.csv[,mt_time_column(data)] <- format(data.csv[,mt_time_column(data)],format="%Y-%m-%d %H:%M:%OS3") ## if time is 00:00:00 it gets rounded just to the date, and if miliseconds are .000 it gets rounded to seconds when saved as csv. This ensures this does not happen. All timestamps will always have miliseconds.
  data.csv
}

# meta.csv first, then link.csv - the order of v2.2.0
writeLink <- function(data, bufferFile, metaFile) {
  write.csv(linkMeta(data = data), metaFile, row.names=FALSE)
  write.csv(linkTable(data = data), bufferFile, row.names=FALSE)
}

# NULL for a buffer without rows
readLink <- function(bufferFile, metaFile) {
  # always includes "coords_x", "coords_y"
  datapy <- read.csv(bufferFile, header=TRUE)
  # always includes crs, tzone, timeColName, trackIdColName
  meta <- read.csv(metaFile, header=TRUE)

  if (dim(datapy)[1]==0) {
    return(NULL)
  }

  datapy[meta$timeColName] <- as.POSIXct(datapy %>% select(meta$timeColName) %>% sapply(as.character) %>% as.vector,format="%Y-%m-%d %H:%M:%S", tz=meta$tzone)
  result <- mt_as_move2(datapy,
                        coords = c("coords_x", "coords_y"),
                        time_column= meta$timeColName,
                        track_id_column= meta$trackIdColName,
                        crs= meta$crs
  )
  result |> dplyr::arrange(mt_track_id(result),mt_time(result))
}
```

- [ ] **Step 4: Reduce the entry scripts to glue**

`r/rds_2_csv.R`:
```r
source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")
source("link.R")

tryCatch(
    {
      Sys.setenv(tz="UTC")

      writeLink(data = readInput(sourceFile()), bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        storeToFile(e, errorFile())
        stop(e) # re-throw the exception
    }
)
```

`r/csv_2_rds.R`:
```r
source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")
source("link.R")

tryCatch(
  {
    Sys.setenv(tz="UTC")

    result <- readLink(bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    # v2.2.0 stores no output at all for a buffer without rows
    if (!is.null(result)) storeResult(result = result, outputFile = outputFile())
  },
  error = function(e)
  {
    # error handler picks up where error was generated
    print(paste("ERROR: ", e))
    storeToFile(e, errorFile())
    stop(e) # re-throw the exception
  }
)
```

`r/.renvignore`:
```text
# test-only code: keeps testthat out of the App's lock, and so out of the hangar inspection
tests/
```

- [ ] **Step 5: Run the tests (dev loop)** — add `r/link.R` to the tar list of Step 2:

```bash
COPYFILE_DISABLE=1 tar --no-xattrs -cf - r/link.R r/tests test/contract | docker run --rm -i rocker/geospatial:4.6.1 bash -c '
  mkdir /w && tar -C /w -xf - && cd /w/r &&
  R -q -s -e "install.packages(c(\"move2\", \"testthat\"), quiet = TRUE)" > /dev/null 2>&1 &&
  Rscript --no-init-file -e "testthat::test_dir(\"tests/testthat\")"' 2>&1 | tail -15
```
Expected: `[ FAIL 0 | … | PASS n ]`. A failure in `test-contract.R` alone means the newest CRAN packages already differ from v2.2.0 — note which case and field, and continue: Step 6 is the binding proof for this task, Task 5 the one for the new stack.

- [ ] **Step 6: Prove the refactoring changes nothing — on v2.2.0 itself**

The overlay runs this checkout's `link.R`, `rds_2_csv.R` and `csv_2_rds.R` inside the production images; their old `src/` is still there.
```bash
OVERLAY=1 test/contract/generate.sh && OVERLAY=1 test/roundtrip/measure.sh && git diff --exit-code test/
```
Expected: exit 0, no diff. Any diff: the refactoring changed behaviour — fix `link.R`, not the goldens.

- [ ] **Step 7: Mutate once**

In `linkTable` change `"%Y-%m-%d %H:%M:%OS3"` to `"%Y-%m-%d %H:%M:%OS2"`, rerun Step 6: `git diff` must show `link.csv` changes in all six cases. Revert the edit, rerun, expect no diff again.

- [ ] **Step 8: Commit**

```bash
git add r/link.R r/.renvignore r/rds_2_csv.R r/csv_2_rds.R r/tests/
git commit -F - <<'EOF'
Move the R logic into testable functions

Both entry scripts were a single top-level tryCatch, so nothing on the
R side could be tested. link.R holds the conversion as functions, the
entry scripts keep only the SDK glue. Running this checkout's R files
inside the v2.2.0 production images reproduces every golden and every
round-trip expectation, so the move changes nothing. Includes the
first R tests: unit tests per function and the contract goldens.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 5: The port — `moveapps`, R 4.6.1, conda from the python co-pilot, one Dockerfile

**Files:**
- Modify: `r/rds_2_csv.R`, `r/csv_2_rds.R`, `r/renv.lock`, `r/renv/activate.R`, `Dockerfile`, `r2python.sh`, `python2r.sh`, `test/Dockerfile`
- Delete: `r/src/` (all six files)

**Interfaces:**
- Consumes: `r/link.R` (Task 4), the pins (Task 2).
- Produces: `Dockerfile` with `ARG BASE`, `ARG CONDA`, `ARG DIRECTION`; images `link-r-python:r2python`, `link-r-python:python2r` built locally on the real co-pilots (used by Tasks 5 and 13).

- [ ] **Step 1: Port the entry scripts to `moveapps`**

`r/rds_2_csv.R`:
```r
library("moveapps")
moveapps::logger.init()
source("link.R")

tryCatch(
    {
      Sys.setenv(tz="UTC")

      writeLink(data = moveapps::readInput(moveapps::sourceFile()), bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        moveapps::storeToFile(e, moveapps::errorFile())
        stop(e) # re-throw the exception
    }
)
```

`r/csv_2_rds.R`:
```r
library("moveapps")
moveapps::logger.init()
source("link.R")

tryCatch(
  {
    Sys.setenv(tz="UTC")

    result <- readLink(bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    # v2.2.0 stores no output at all for a buffer without rows
    if (!is.null(result)) moveapps::storeResult(result = result, outputFile = moveapps::outputFile())
  },
  error = function(e)
  {
    # error handler picks up where error was generated
    print(paste("ERROR: ", e))
    moveapps::storeToFile(e, moveapps::errorFile())
    stop(e) # re-throw the exception
  }
)
```

```bash
git rm -r -q r/src
```

- [ ] **Step 2: Regenerate the lock inside the R co-pilot**

P3M binaries make the emulated install minutes instead of hours; the versions are CRAN's today, and the lock records CRAN as its repository.
```bash
CO_PILOT=registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-r:v4.0.0_sdk-v1.0.3_geospatial-4.6.1_4674
container="$(docker create --platform linux/amd64 --entrypoint bash -w /home/moveapps \
  -e RENV_CONFIG_REPOS_OVERRIDE=https://p3m.dev/cran/__linux__/noble/latest "$CO_PILOT" -c '
  set -o errexit
  cp -R /tmp/in /tmp/r && cd /tmp/r
  cp /home/moveapps/co-pilot-r/renv/activate.R renv/activate.R
  rm -f renv.lock
  R -q -e "renv::install(c(\"move2\", \"sf\", \"dplyr\", \"vctrs\", \"purrr\", \"rlang\", \"movestore/moveapps-sdk-r-package@v1.0.3\"), prompt = FALSE); renv::snapshot(prompt = FALSE, repos = c(CRAN = \"https://cloud.r-project.org\"))"')"
docker cp r "$container:/tmp/in"
docker start --attach "$container" 2>&1 | tail -20
docker cp "$container:/tmp/r/renv.lock" r/renv.lock
docker cp "$container:/tmp/r/renv/activate.R" r/renv/activate.R
docker rm "$container" > /dev/null
```

- [ ] **Step 3: Check the lock**

```bash
jq -r '.R.Version, .Packages.renv.Version, .Packages.moveapps.Version, .Packages.moveapps.RemoteRef' r/renv.lock
jq -r '.Packages | keys[]' r/renv.lock | grep -x -E 'move2|sf|dplyr|vctrs|purrr|rlang|moveapps|testthat|httr'
grep -m1 'version <-' r/renv/activate.R
```
Expected: `4.6.1`, `1.2.4`, `1.0.3`, `v1.0.3`; the second list shows exactly the seven packages `dplyr moveapps move2 purrr rlang sf vctrs` — **no** `testthat`, **no** `httr`; `version <- "1.2.4"`.

- [ ] **Step 4: Rewrite `Dockerfile`**

```dockerfile
# Builds either translator App - `DIRECTION` below says which. The platform passes no build
# arguments: BASE and CONDA fall back to their defaults, and DIRECTION must be set in the copy of this
# file that goes onto the App version (see README).
ARG BASE=registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-r:v4.0.0_sdk-v1.0.3_geospatial-4.6.1_4674
# The python co-pilot, for its conda: FROM condaforge/miniforge3:26.7.2-0, /opt/conda untouched.
# Taken from the platform's registry, not Docker Hub: no App version has ever pulled from elsewhere,
# and the platform's builder holds no Docker Hub credentials.
ARG CONDA=registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v1-python:v3.1.0

FROM ${CONDA} AS conda

FROM ${BASE}
COPY --from=conda /opt/conda /opt/conda
ENV PATH=/opt/conda/bin:$PATH

# the app
ENV PROJECT_DIR=$HOME/co-pilot-r
WORKDIR $PROJECT_DIR

# the python part, built like every python App
WORKDIR $PROJECT_DIR/python
COPY --chown=$UID:$GID python/environment.yml /tmp/
# keep in mind that anaconda aka channel `conda` is blocked in production env
# https://gitlab.mpcdf.mpg.de/mpcdf-hpc-cloud/mvpr-moveapps/-/issues/29
# miniforge uses channel `conda-forge` as default - so nothing to do here
ENV ENV_PREFIX=$PROJECT_DIR/python-env
RUN conda env create --prefix $ENV_PREFIX --file /tmp/environment.yml && \
    conda clean --all --yes

# the r part: the translator's own renv project in r/
WORKDIR $PROJECT_DIR/r
# cleanup: the co-pilot's own renv project and entry point; the translator brings both
RUN rm -rf ../renv ../renv.lock ../.Rprofile ../RFunction.R ../app.R
# renv: restore the current snapshot
COPY --chown=$UID:$GID r/renv.lock r/.Rprofile ./
COPY --chown=$UID:$GID r/renv/activate.R r/renv/settings.dcf ./renv/
RUN R -e 'renv::restore()'
# be prepared for the hangar inspection
RUN cp renv.lock ../

# the project: both directions, so both Apps share every layer up to here
WORKDIR $PROJECT_DIR
COPY --chown=$UID:$GID python/csv_2_pickle.py python/transform_to_pickle.py python/pickle_2_csv.py python/transform_to_csv.py ./python/
COPY --chown=$UID:$GID r/link.R r/rds_2_csv.R r/csv_2_rds.R ./r/

# The one line in which the two Apps differ: r2python (move2_loc to MovingPandas) or python2r
# (MovingPandas to move2_loc). No default on purpose - a forgotten edit must fail the build, not
# silently build the other App. Declared last: a changed ARG invalidates every RUN after it.
ARG DIRECTION
RUN case "$DIRECTION" in r2python|python2r) ;; *) echo "DIRECTION must be r2python or python2r" >&2; exit 1 ;; esac
COPY --chown=$UID:$GID ${DIRECTION}.sh start-process.sh
```

- [ ] **Step 5: Start python via `conda run`**

`r2python.sh` — replace the shebang with `#!/bin/bash` and the python line with:
```bash
(cd python && conda run --no-capture-output --prefix "$ENV_PREFIX" python csv_2_pickle.py)
```
`python2r.sh` — the same shebang, and:
```bash
(cd python && conda run --no-capture-output --prefix "$ENV_PREFIX" python pickle_2_csv.py)
```
Leave the rest of both files unchanged. (`--no-capture-output`: without it conda swallows the output, a failure included. The login shell existed only for `conda activate`.)

- [ ] **Step 6: Align `test/Dockerfile` with the python co-pilot's conda**

`FROM condaforge/miniforge3:26.3.2-3` → `FROM condaforge/miniforge3:26.7.2-0`. Update its comment: the tag is the python co-pilot's own base, and `test/coherence.R` (Task 6) holds CI to it.

- [ ] **Step 7: Prove `/opt/conda` of the python co-pilot is Miniforge's**

```bash
for image in registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v1-python:v3.1.0 condaforge/miniforge3:26.7.2-0; do
  docker run --rm --platform linux/amd64 --entrypoint sh "$image" -c 'cd /opt/conda && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum'
done
```
Expected: two identical sums. Different: stop and report — the `CONDA` override in CI would then not mirror production.

- [ ] **Step 8: Build both Apps on the real co-pilots** (background; the first build compiles every R package from source, emulated — expect well over 30 minutes)

```bash
docker build --platform linux/amd64 --build-arg DIRECTION=r2python -t link-r-python:r2python . > /tmp/link-r2python-build.log 2>&1
docker build --platform linux/amd64 --build-arg DIRECTION=python2r -t link-r-python:python2r . > /tmp/link-python2r-build.log 2>&1
```
Expected: both logs end with `naming to docker.io/library/link-r-python:…`; the second build shows every step up to `ARG DIRECTION` as `CACHED`.

- [ ] **Step 9: A missing or wrong `DIRECTION` must fail**

```bash
docker build --platform linux/amd64 . 2>&1 | grep -E 'DIRECTION must be|ERROR' | head -3
docker build --platform linux/amd64 --build-arg DIRECTION=sideways . 2>&1 | grep -E 'DIRECTION must be|ERROR' | head -3
```
Expected: both print `DIRECTION must be r2python or python2r` and an `ERROR` line.

- [ ] **Step 10: The port reproduces v2.2.0**

```bash
R2PY_IMAGE=link-r-python:r2python PY2R_IMAGE=link-r-python:python2r test/contract/generate.sh
R2PY_IMAGE=link-r-python:r2python PY2R_IMAGE=link-r-python:python2r test/roundtrip/measure.sh
git diff --exit-code test/
```
Expected: exit 0. Any diff is a behaviour change by R 4.6.1 or the new packages: stop, report the diff, do not update the pins.

- [ ] **Step 11: The R tests pass in the App image**

```bash
container="$(docker create --platform linux/amd64 --entrypoint bash -w /home/moveapps/co-pilot-r/r link-r-python:r2python -c \
  'R -q -e "renv::install(\"testthat@3.3.2\")" > /dev/null && Rscript -e "testthat::test_dir(\"tests/testthat\")"')"
docker cp r/tests "$container:/home/moveapps/co-pilot-r/r/tests"
docker cp test "$container:/home/moveapps/co-pilot-r/test"
docker start --attach "$container" 2>&1 | tail -8
docker rm "$container" > /dev/null
```
Expected: `[ FAIL 0 | … ]`.

- [ ] **Step 12: Commit**

```bash
git add -A r/ Dockerfile r2python.sh python2r.sh test/Dockerfile
git commit -F - <<'EOF'
Port the translators to the moveapps R package

Since R co-pilot v4 the SDK is the moveapps package and the image has
no src/, so the old build failed at mv ../src. The entry scripts now
call the package; its readRdsInput needs no move1, so the patched copy
goes too. The lock moves to R 4.6.1.

conda comes from the python co-pilot's image instead of a Miniforge
installer fetched from "latest", so the python half resolves like every
python App. One Dockerfile builds both Apps: DIRECTION has no default,
so a forgotten edit fails the build instead of building the other App.

Built on the real co-pilots, both Apps reproduce every v2.2.0 golden
and round-trip expectation.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 6: CI — the real Dockerfile on a public stand-in, tested inside the images

**Files:**
- Create: `test/co-pilot-r.Dockerfile`, `test/docker-bake.hcl`, `test/app-test.Dockerfile`, `test/coherence.R`, `test/roundtrip/run.sh`, `test/roundtrip/compare.R`
- Modify: `.dockerignore`, `.github/workflows/test.yml`

**Interfaces:**
- Consumes: `describe.R` functions (Task 2), `stage-*.sh` (Task 2), the Dockerfile ARGs (Task 5).
- Produces: bake targets `co-pilot-r`, `app-r2python`, `app-python2r`, `test`, `app-without-direction`, `app-with-invalid-direction`; bake variables `CACHE` (`gha` or empty), `FRESH` (`true`/`false`), `CONDA`.

- [ ] **Step 1: Write `test/co-pilot-r.Dockerfile`**

```dockerfile
########################################################################################################################
# A public stand-in for the private R co-pilot, so CI can build the real App Dockerfile.
# Mirrors co-pilot-v1/co-pilot-r/r/Dockerfile of movestore-groundcontrol: same rocker digest, user, directories and
# renv setup. Left out: the Java part, and the co-pilot's own renv project - the translator brings `moveapps` through
# r/renv.lock. Keep the digest in step with the co-pilot; test/coherence.R can check the R version, not the digest,
# because the co-pilot's registry is private.
########################################################################################################################
# rocker/geospatial:4.6.1
FROM rocker/geospatial@sha256:4cee92a576e26c31546860eb252290f8f259e8236d49600d6bee695dfb96cae5

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
# packages that build a vendored C++ dependency need it, e.g. s2 (Abseil)
    cmake \
    && apt-get clean

ARG username=moveapps
ARG uid=1001
ARG gid=staff
ENV USER=$username
ENV UID=$uid
ENV GID=$gid
ENV HOME=/home/$USER

RUN adduser --disabled-password \
    --gecos "Non-root user" \
    --uid $UID \
    --ingroup $GID \
    --home $HOME \
    $USER
RUN install -d -o moveapps -g staff $HOME/co-pilot-r
RUN install -d -o moveapps -g staff $HOME/.cache/R
USER $USER
WORKDIR $HOME/co-pilot-r

ENV RENV_PATHS_CACHE=$HOME/.cache/R/renv
# The one deviation from the co-pilot, which compiles from https://cloud.r-project.org: P3M binaries of the very
# versions the lock pins, so a cold CI run takes minutes. A version P3M lacks falls back to source (hence cmake).
ENV RENV_CONFIG_REPOS_OVERRIDE=https://p3m.dev/cran/__linux__/noble/latest
ENV RENV_CONFIG_SANDBOX_ENABLED=FALSE

RUN R -e "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv')"
```

- [ ] **Step 2: Write `test/docker-bake.hcl`**

```hcl
# Builds and tests both translator Apps from the real Dockerfile, on public images only:
#
#   co-pilot-r (stand-in) --BASE--+--> app-r2python --+
#   miniforge -----------CONDA----+--> app-python2r --+--> test: R unit tests, round trip, coherence
#
#   docker buildx bake -f test/docker-bake.hcl test

# "gha" inside GitHub Actions; empty elsewhere, where no Actions cache exists
variable "CACHE" {
  default = ""
}

# "true" for the runs that must resolve everything from scratch (see .github/workflows/test.yml)
variable "FRESH" {
  default = "false"
}

# the python co-pilot's own base; test/coherence.R holds test/Dockerfile to the same tag
variable "CONDA" {
  default = "condaforge/miniforge3:26.7.2-0"
}

function "cacheFrom" {
  params = [scope]
  result = CACHE == "gha" && FRESH != "true" ? ["type=gha,scope=${scope}"] : []
}

function "cacheTo" {
  params = [scope]
  result = CACHE == "gha" ? ["type=gha,mode=max,scope=${scope},ignore-error=true"] : []
}

target "co-pilot-r" {
  context = "."
  dockerfile = "test/co-pilot-r.Dockerfile"
  platforms = ["linux/amd64"]
  no-cache = FRESH == "true"
  cache-from = cacheFrom("co-pilot-r")
  cache-to = cacheTo("co-pilot-r")
}

target "app" {
  name = "app-${direction}"
  matrix = {
    direction = ["r2python", "python2r"]
  }
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["link-r-python:${direction}"]
  contexts = {
    co-pilot-r = "target:co-pilot-r"
  }
  args = {
    BASE = "co-pilot-r"
    CONDA = CONDA
    DIRECTION = direction
  }
  no-cache = FRESH == "true"
  cache-from = cacheFrom("app-${direction}")
  cache-to = cacheTo("app-${direction}")
}

target "test" {
  context = "."
  dockerfile = "test/app-test.Dockerfile"
  platforms = ["linux/amd64"]
  contexts = {
    app-r2python = "target:app-r2python"
    app-python2r = "target:app-python2r"
  }
  no-cache = FRESH == "true"
  cache-from = cacheFrom("test")
  cache-to = cacheTo("test")
}

# Both must fail. The platform passes no build arguments, so a Dockerfile copy without its DIRECTION
# edit has to be refused rather than built.
target "app-without-direction" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64"]
  contexts = {
    co-pilot-r = "target:co-pilot-r"
  }
  args = {
    BASE = "co-pilot-r"
    CONDA = CONDA
  }
}

target "app-with-invalid-direction" {
  inherits = ["app-without-direction"]
  args = {
    DIRECTION = "sideways"
  }
}
```

- [ ] **Step 3: Write `test/roundtrip/compare.R`**

```r
# Checks a round trip against its pins (see describe.R), then the invariants no pin may relax: the
# track of every row, the coordinates, the crs, and every input column present on the way back.
#   Rscript compare.R <cases> <expected.csv> <classes.csv>
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)))
source(file.path(here, "describe.R"))

args <- commandArgs(trailingOnly = TRUE)
described <- describeAll(cases = args[1])
failures <- character()

# the pins, line by line
actualExpected <- tempfile(fileext = ".csv")
actualClasses <- tempfile(fileext = ".csv")
writeDescription(described = described, expectedFile = actualExpected, classesFile = actualClasses)
for (files in list(c(args[2], actualExpected), c(args[3], actualClasses))) {
  pinned <- readLines(files[1])
  measured <- readLines(files[2])
  failures <- c(failures,
                paste0(basename(files[1]), ", pinned but not measured: ", setdiff(pinned, measured)),
                paste0(basename(files[1]), ", measured but not pinned: ", setdiff(measured, pinned)))
}

# the invariants
for (case in described) {
  if (is.null(case$aligned)) next
  name <- case$summary$case
  input <- case$aligned$input
  output <- case$aligned$output

  if (nrow(input) != nrow(output)) {
    failures <- c(failures, sprintf("%s: %d input rows in the kept tracks, %d rows back", name, nrow(input), nrow(output)))
    next
  }
  if (!identical(as.character(mt_track_id(input)), as.character(mt_track_id(output)))) {
    failures <- c(failures, sprintf("%s: the track of a row changed", name))
  }
  coordinatesIn <- st_coordinates(input)
  coordinatesOut <- st_coordinates(output)
  if (any(abs(coordinatesIn - coordinatesOut) > 1e-12 * pmax(1, abs(coordinatesIn)))) {
    failures <- c(failures, sprintf("%s: coordinates changed", name))
  }
  if (st_crs(case$input) != st_crs(case$output)) {
    failures <- c(failures, sprintf("%s: crs changed", name))
  }
  lost <- setdiff(case$namesIn, case$namesOut)
  if (length(lost) > 0) {
    failures <- c(failures, sprintf("%s: columns lost: %s", name, paste(lost, collapse = ", ")))
  }
}

if (length(failures) > 0) {
  cat(failures, sep = "\n")
  quit(status = 1)
}
cat(sprintf("round trip: %d cases as pinned\n", length(described)))
```

- [ ] **Step 4: Write `test/roundtrip/run.sh`** and `chmod +x` it

```bash
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
```

- [ ] **Step 5: Write `test/coherence.R`**

```r
# The versions pinned in separate files must agree - nothing else compares them.
#   Rscript coherence.R <repository root>        (inside the test image: R is the stand-in's)
root <- commandArgs(trailingOnly = TRUE)[1]

field <- function(text, pattern) {
  match <- regmatches(text, regexec(pattern, text))[[1]]
  if (length(match) == 2) match[2] else NA_character_
}

base <- grep("^ARG BASE=", readLines(file.path(root, "Dockerfile")), value = TRUE)
lock <- jsonlite::fromJSON(file.path(root, "r", "renv.lock"))
bake <- paste(readLines(file.path(root, "test", "docker-bake.hcl")), collapse = "\n")
testDockerfile <- paste(readLines(file.path(root, "test", "Dockerfile")), collapse = "\n")

check <- function(label, left, right) {
  ok <- !is.na(left) && !is.na(right) && identical(left, right)
  cat(sprintf("%s %s: %s / %s\n", if (ok) "ok  " else "FAIL", label, left, right))
  ok
}

results <- c(
  check("R of this image / R in r/renv.lock", as.character(getRversion()), lock$R$Version),
  check("R in r/renv.lock / geospatial-X of BASE", lock$R$Version, field(base, "_geospatial-([0-9.]+)_")),
  check("moveapps in r/renv.lock / sdk-vX of BASE", lock$Packages$moveapps$Version, field(base, "_sdk-v([0-9.]+)_")),
  check("Miniforge CI passes as CONDA / Miniforge of test/Dockerfile",
        field(bake, 'default = "condaforge/miniforge3:([0-9A-Za-z._-]+)"'),
        field(testDockerfile, "FROM condaforge/miniforge3:([0-9A-Za-z._-]+)"))
)
if (!all(results)) quit(status = 1)
```

- [ ] **Step 6: Write `test/app-test.Dockerfile`**

```dockerfile
# Runs the coherence check, the R unit tests and the round trip inside the real App images.
FROM app-r2python

# the python -> R entry point; everything else in the two images is identical
COPY --from=app-python2r --chown=$UID:$GID /home/moveapps/co-pilot-r/start-process.sh /home/moveapps/co-pilot-r/start-process-python2r.sh

# testthat is a test dependency only: installed here, never part of the App's lock
WORKDIR /home/moveapps/co-pilot-r/r
RUN R -q -e 'renv::install("testthat@3.3.2")'

WORKDIR /home/moveapps/co-pilot-r
COPY --chown=$UID:$GID Dockerfile ./Dockerfile
COPY --chown=$UID:$GID test/ ./test/
COPY --chown=$UID:$GID r/tests/ ./r/tests/
COPY --chown=$UID:$GID r/data/raw/ ./r/data/raw/

RUN cd r && Rscript ../test/coherence.R ..
RUN cd r && Rscript -e 'testthat::test_dir("tests/testthat")'
RUN test/roundtrip/run.sh
```

- [ ] **Step 7: Let the samples into the build context** — `.dockerignore`, directly after `r/data/`:

```text
# ...except the samples the round trip reads in CI
!r/data/raw
```

- [ ] **Step 8: Run the whole suite locally** (background; cold: rocker pull + emulated build)

Run: `docker buildx bake -f test/docker-bake.hcl test > /tmp/link-bake.log 2>&1`
Expected in the log: four `ok` lines from `coherence.R`, testthat `[ FAIL 0 | …`, `round trip: 12 cases as pinned` (9 sample inputs, 2 synthetic, 1 empty — the data lines of `expected.csv`), and the build finishing without `ERROR`.

- [ ] **Step 9: The negative targets fail, for the right reason**

```bash
for target in app-without-direction app-with-invalid-direction; do
  if docker buildx bake -f test/docker-bake.hcl "$target" > "/tmp/$target.log" 2>&1; then echo "BUILT $target"; fi
  grep -c 'DIRECTION must be r2python or python2r' "/tmp/$target.log"
done
```
Expected: no `BUILT` line; two counts ≥ 1.

- [ ] **Step 10: Mutate — every guard must bite**

One at a time, each followed by Step 8, each reverted with `git checkout -- <file>`:
1. `test/roundtrip/expected.csv`: change the `rows_out` of `input1_move2loc_LatLon` → the build fails with `pinned but not measured`.
2. `test/Dockerfile`: tag `26.7.2-0` → `26.7.2-1` → `FAIL Miniforge CI passes as CONDA …`.
3. `r/tests/testthat/test-link-meta.R`: expected crs `"EPSG:4326"` → `"EPSG:4327"` → testthat `FAIL 1`.

- [ ] **Step 11: Add the CI job** — `.github/workflows/test.yml`

Extend the comment above `env: FRESH` with one sentence:
```yaml
# The `app` job's images resolve the same open environment inside the App Dockerfile.
```
Append the job (the existing `test` job keeps its id and name):
```yaml
  app:
    name: App images
    runs-on: ubuntu-latest
    permissions:
      contents: read
    # a first guess with headroom; set from the first measured cold run
    timeout-minutes: 90
    env:
      CACHE: gha

    steps:
      - name: Checkout repository
        uses: actions/checkout@v7

      - name: Setup Docker buildx
        uses: docker/setup-buildx-action@v4

      - name: Build both Apps and test them inside the images
        uses: docker/bake-action@v7
        with:
          source: .
          files: test/docker-bake.hcl
          targets: test

      # The platform passes no build arguments, so a Dockerfile copy without its DIRECTION edit must be
      # refused. The builder still holds every layer from the step above, so this costs the last ones only;
      # the grep makes sure the build failed at the check, not somewhere else.
      - name: A build without a valid DIRECTION must fail
        env:
          CACHE: ''
        run: |
          for target in app-without-direction app-with-invalid-direction; do
            if docker buildx bake -f test/docker-bake.hcl "$target" > "$target.log" 2>&1; then
              echo "::error::$target was built"
              exit 1
            fi
            if ! grep -q 'DIRECTION must be r2python or python2r' "$target.log"; then
              cat "$target.log"
              echo "::error::$target failed for another reason"
              exit 1
            fi
          done
```

- [ ] **Step 12: Commit**

```bash
git add test/ .dockerignore .github/workflows/test.yml
git commit -F - <<'EOF'
Build and test the App images in CI

The App Dockerfile was built by nothing but the platform, which is how
the mv ../src break stayed invisible. CI now builds the real Dockerfile
for both directions, on a public stand-in for the private co-pilot, and
runs the R unit tests, the round trip and a coherence check of the
version pins inside the images. A build without a valid DIRECTION must
fail, at the check.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

The five defect fixes follow, one task and one commit each. Each fix changes the pins it corrects — the diff of `expected.csv`, `classes.csv` or a golden is part of its evidence. Rebuild and re-measure after each fix with the local bake images (P3M; same pinned versions as production):
```bash
docker buildx bake -f test/docker-bake.hcl --load app-r2python app-python2r
R2PY_IMAGE=link-r-python:r2python PY2R_IMAGE=link-r-python:python2r test/roundtrip/measure.sh
```

### Task 7: Defect 1 — an empty collection yields the NULL output

**Files:**
- Modify: `python/transform_to_csv.py`, `python/tests/test_transform_to_csv.py`, `r/link.R`, `r/csv_2_rds.R`, `r/tests/testthat/test-read-link.R`, `test/roundtrip/expected.csv`

- [ ] **Step 1: Failing python test** — add to `TransformToCsvTestCase`:

```python
    def test_it_should_write_empty_files_for_an_empty_trajectory_collection(self):
        # arrange
        empty = os.path.join(self.tmp.name, 'empty_output_file')
        pd.to_pickle(mpd.TrajectoryCollection([]), empty, compression='gzip')
        link = os.path.join(self.tmp.name, 'link.csv')
        meta = os.path.join(self.tmp.name, 'meta.csv')

        # act
        self.sut.convert(input_data_file_name=empty, output_file_name=link, output_meta_file_name=meta)

        # assert: empty files tell R to hand on the NULL result
        self.assertEqual(0, os.path.getsize(link))
        self.assertEqual(0, os.path.getsize(meta))
```
with `import movingpandas as mpd` and `import pandas as pd` at the top. Run `docker build -f test/Dockerfile .` → FAIL, `ValueError: No objects to concatenate`.

- [ ] **Step 2: Failing R test** — add to `test-read-link.R`:

```r
test_that("readLink returns NULL for an empty buffer file", {
  # arrange: python writes one for an empty TrajectoryCollection
  buffer <- tempfile(fileext = ".csv")
  file.create(buffer)
  meta <- tempfile(fileext = ".csv")
  file.create(meta)

  # act
  actual <- readLink(bufferFile = buffer, metaFile = meta)

  # assert
  expect_null(actual)
})
```
Run the dev loop (Task 4, Step 5) → FAIL, `no lines available in input`.

- [ ] **Step 3: Fix python** — in `TransformToCsv.convert`, directly after reading the pickle:

```python
        if len(data.trajectories) == 0:
            # nothing to hand over, not even a crs: empty files tell R to store the NULL result
            open(output_file_name, 'w').close()
            open(output_meta_file_name, 'w').close()
            return
```

- [ ] **Step 4: Fix R** — at the top of `readLink`:

```r
  # python writes an empty buffer for an empty TrajectoryCollection
  if (file.size(bufferFile) == 0) {
    return(NULL)
  }
```
and in `r/csv_2_rds.R` replace the two lines from `result <- readLink(` to the `if (!is.null(result))` line by:
```r
    # NULL for an empty buffer: storeResult then writes the empty file the next App reads as NULL input
    moveapps::storeResult(result = readLink(bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META")), outputFile = moveapps::outputFile())
```

- [ ] **Step 5: Tests green, pins moved** — python suite, dev loop, then rebuild + re-measure (see above). Expected diff in `expected.csv`: only the `empty_trajectory_collection` line, `python2r_exit` `1` → `0` and `rows_out` empty → `0`. `docker buildx bake -f test/docker-bake.hcl test` green.

- [ ] **Step 6: Commit**

```bash
git add python/ r/ test/roundtrip/expected.csv
git commit -F - <<'EOF'
Hand on NULL for an empty TrajectoryCollection

The README promises a NULL object, but the python half failed with
"No objects to concatenate", and the R half would not have stored an
output for zero rows either. Python now writes empty files, and R
stores the NULL result: the empty file the next R App rejects with
code 10.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 8: Defect 2 — transmit UTC instants, not wall-clock times

**Files:**
- Modify: `r/link.R`, `r/tests/testthat/test-link-table.R`, `python/transform_to_pickle.py`, `python/tests/test_transform_to_pickle.py`, `python/environment.yml` (one comment sentence), `test/contract/berlin/{link.csv,py/link.csv}`, `test/roundtrip/{expected.csv,classes.csv}`

- [ ] **Step 1: Failing R test** — add to `test-link-table.R`:

```r
test_that("linkTable writes UTC instants, whatever the tzone", {
  # arrange
  data <- readCase("berlin")

  # act
  actual <- linkTable(data = data)

  # assert: 06:40 UTC is 08:40 in Berlin; link.csv carries the instant, meta.csv the zone
  expect_equal(actual$timestamp[1], "2021-07-01 06:40:00.000")
})
```
Dev loop → FAIL: `"2021-07-01 08:40:00.000"`.

- [ ] **Step 2: Rewrite the python timezone tests** — they pin wall-clock semantics, which is the defect. In `test_transform_to_pickle.py` (keep their `# prepare / # execute / # verify` words):
- `test_apply_timezone_plusOffset`: expected `timestamp_tz` `datetime.datetime(2013, 8, 8, 8, 47, 31, tzinfo=ZoneInfo('Europe/Berlin'))`, `timestamp_utc` `datetime.datetime(2013, 8, 8, 6, 47, 31)`; comment `# csv value: 2013-08-08 06:47:31, a UTC instant`.
- `test_apply_timezone_name_kolkata`: expected `timestamp_tz` `datetime.datetime(2013, 8, 8, 12, 17, 31, tzinfo=ZoneInfo('Asia/Kolkata'))`, `timestamp_utc` `datetime.datetime(2013, 8, 8, 6, 47, 31)`.
- `test_apply_timezone_name_utc`: unchanged.
- `test_ambiguous_dst_timestamp_should_raise_error` → rename `test_an_instant_in_the_repeated_dst_hour_should_convert`:
  ```python
        # verify: 01:16:03 UTC is 01:16:03 GMT, just after British Summer Time ended at 01:00 UTC
        actual = self.sut.adjust_timestamps(data, timezone='Europe/London', time_col_name='timestamp')
        self.assertEqual(datetime.datetime(2013, 10, 27, 1, 16, 3, tzinfo=datetime.timezone.utc), actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2013, 10, 27, 1, 16, 3), actual['timestamp_utc'][0].to_pydatetime())
  ```
- `test_non_existent_timestamp_should_raise_error` → rename `test_an_instant_in_the_skipped_dst_hour_should_convert`:
  ```python
        # verify: 01:24:20 UTC is 02:24:20 BST, British Summer Time began at 01:00 UTC
        actual = self.sut.adjust_timestamps(data, timezone='Europe/London', time_col_name='timestamp')
        self.assertEqual(datetime.datetime(2014, 3, 30, 1, 24, 20, tzinfo=datetime.timezone.utc), actual['timestamp_tz'][0].to_pydatetime())
        self.assertEqual(datetime.datetime(2014, 3, 30, 1, 24, 20), actual['timestamp_utc'][0].to_pydatetime())
  ```
- remove `import pytz`, now unused.

Python suite → the four changed tests FAIL.

- [ ] **Step 3: Fix R** — in `linkTable`, the format line gains `tz="UTC"` and a comment:

```r
  ## UTC instants: a wall-clock time repeats in the autumn DST hour and python could not tell the two apart; meta.csv keeps the tzone
  data.csv[,mt_time_column(data)] <- format(data.csv[,mt_time_column(data)],format="%Y-%m-%d %H:%M:%OS3", tz="UTC") ## if time is 00:00:00 it gets rounded just to the date, and if miliseconds are .000 it gets rounded to seconds when saved as csv. This ensures this does not happen. All timestamps will always have miliseconds.
```

- [ ] **Step 4: Fix python** — in `adjust_timestamps`, the `timestamp_tz` line:

```python
        # link.csv carries UTC instants; `timezone` is how R displayed them
        # kudos: https://stackoverflow.com/a/18912631/810944
        data['timestamp_tz'] = data[time_col_name].apply(lambda x: x.tz_localize('UTC').tz_convert(timezone))
```
In `python/environment.yml` delete the sentence `It also drops the pytz dependency that` … `borrows transitively.` — the tests no longer borrow it.

- [ ] **Step 5: Regenerate the goldens with the fixed images, check the diff**

```bash
docker buildx bake -f test/docker-bake.hcl --load app-r2python app-python2r
R2PY_IMAGE=link-r-python:r2python PY2R_IMAGE=link-r-python:python2r test/contract/generate.sh
R2PY_IMAGE=link-r-python:r2python PY2R_IMAGE=link-r-python:python2r test/roundtrip/measure.sh
git diff --stat test/
```
Expected: `test/contract/berlin/link.csv` (time column 08:40 → 06:40 etc.), `test/contract/berlin/py/link.csv` (the `timestamp` column, now UTC); `expected.csv`: only the `dst_ambiguous` line (`r2python_exit` 0, `python2r_exit` 0, `rows_out` 2, `tracks_out` 1, `0.000`, `timestamp_utc`, `UTC`); `classes.csv`: new `dst_ambiguous` lines only. No other golden changes — UTC data are byte-identical.

- [ ] **Step 6: All suites green** — python suite, dev loop, `docker buildx bake -f test/docker-bake.hcl test`.

- [ ] **Step 7: Commit**

```bash
git add r/ python/ test/
git commit -F - <<'EOF'
Hand timestamps to python as UTC instants

R wrote wall-clock times and python re-localised them, so two fixes an
hour apart in the repeated autumn hour became the same local time and
the App failed with AmbiguousTimeError. link.csv now carries UTC;
meta.csv still names the zone and python converts. UTC data - all real
Movebank data - stay byte-identical.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 9: Defect 3 — keep sub-second times on the way back

**Files:**
- Modify: `r/link.R`, `r/tests/testthat/test-read-link.R`, `r/tests/testthat/test-contract.R`, `test/roundtrip/expected.csv`

- [ ] **Step 1: Turn the pinned tests into the corrected behaviour**

In `test-read-link.R` replace `readLink truncates sub-second times (v2.2.0, pinned)` by:
```r
test_that("readLink keeps sub-second times", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y",
    "2021-07-01 06:40:00.123,a,1,2",
    "2021-07-01 06:40:01.000,a,1,2"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_equal(as.numeric(mt_time(actual))[1] %% 1, 0.123, tolerance = 1e-6)
})
```
In `test-contract.R` the last assertion becomes exact:
```r
    # assert
    kept <- input[as.character(mt_track_id(input)) %in% as.character(mt_track_id(actual)), ]
    expect_equal(nrow(actual), nrow(kept))
    expect_equal(sf::st_crs(actual), sf::st_crs(input))
    expect_equal(sort(as.numeric(mt_time(actual))), sort(as.numeric(mt_time(kept))), tolerance = 1e-6)
```
Dev loop → FAIL for the unit test and for the `subsecond` contract case.

- [ ] **Step 2: Fix** — in `readLink`, `format="%Y-%m-%d %H:%M:%S"` → `format="%Y-%m-%d %H:%M:%OS"`, with the comment `# %OS: python writes fractions of a second, %S would drop them`.

- [ ] **Step 3: Rebuild, re-measure** (see above). Expected diff: `expected.csv` lines `input2_move2loc_LatLon` and `input2_move2loc_Mollweide`, `max_time_deviation_s` `0.999` → `0.000`, nothing else. All suites green.

- [ ] **Step 4: Commit**

```bash
git add r/ test/roundtrip/expected.csv
git commit -F - <<'EOF'
Keep sub-second times from python

Python writes fractions of a second, R parsed them with %S and dropped
them: 75 fixes of the stork sample came back up to 0.999 s early.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 10: Defect 4 — warn about the tracks movingpandas drops

**Files:**
- Modify: `python/transform_to_pickle.py`, `python/tests/test_transform_to_pickle.py`, `test/roundtrip/expected.csv`

- [ ] **Step 1: Failing test** — add to `TransformToPickleTestCase` (imports `contextlib`, `io`, `pandas as pd`):

```python
    def test_it_should_warn_about_every_track_movingpandas_drops(self):
        # arrange: track `a` has one fix, movingpandas needs two for a trajectory
        data = pd.DataFrame({
            'track': ['a', 'b', 'b'],
            'timestamp_utc': pd.to_datetime(['2021-07-01 06:40', '2021-07-01 06:40', '2021-07-01 06:46']),
            'coords_x': [1.0, 2.0, 2.1],
            'coords_y': [1.0, 2.0, 2.1],
        })
        output = io.StringIO()

        # act
        with contextlib.redirect_stdout(output):
            self.sut.create_moving_pandas(data=data, projection='EPSG:4326', track_id_col_name='track')

        # assert
        actual = [line for line in output.getvalue().splitlines() if line.startswith('[WARN]')]
        self.assertEqual(['[WARN] track a dropped: a trajectory needs at least two fixes, it has 1'], actual)
```
Python suite → FAIL, `[] != [...]`.

- [ ] **Step 2: Fix** — in `TransformToPickle.create_moving_pandas`, after building `move`:

```python
        self.warn_about_dropped_tracks(data=data, move=move, track_id_col_name=track_id_col_name)
```
and the new method:
```python
    def warn_about_dropped_tracks(self, data, move, track_id_col_name):
        # movingpandas needs two fixes for a trajectory and drops a track with fewer without a word;
        # the loss cannot be avoided in this format, but it must not stay silent
        kept = {trajectory.id for trajectory in move.trajectories}
        rows_per_track = data[track_id_col_name].value_counts()
        for track_id, rows in sorted(rows_per_track.items(), key=lambda item: str(item[0])):
            if track_id not in kept:
                print(f'[WARN] track {track_id} dropped: a trajectory needs at least two fixes, it has {rows}')
```

- [ ] **Step 3: Rebuild, re-measure.** Expected diff: `expected.csv` line `input_move2loc_List`, `dropped_tracks_warned` `0` → `3`, nothing else. All suites green.

- [ ] **Step 4: Commit**

```bash
git add python/ test/roundtrip/expected.csv
git commit -F - <<'EOF'
Warn about the tracks movingpandas drops

A track with a single fix cannot become a trajectory, and movingpandas
drops it without a word: the List sample goes in with 4 tracks and
comes back with 1. The format cannot keep them, so the App log now
names every dropped track and its number of fixes.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 11: Defect 5 — logical comes back as logical

**Files:**
- Modify: `r/link.R`, `r/tests/testthat/test-read-link.R`, `test/roundtrip/classes.csv`

- [ ] **Step 1: Turn the pinned test into the corrected behaviour** — replace `readLink leaves python's True and False as text (v2.2.0, pinned)` by:

```r
test_that("readLink turns python's True, False and missing value back into logical", {
  # arrange: pandas writes a missing value as an empty field
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y,visible,comment",
    "2021-07-01 06:40:00,a,1,2,True,True story",
    "2021-07-01 06:46:00,a,1,2,False,",
    "2021-07-01 06:52:00,a,1,2,,x"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert: a column with other text stays text
  expect_equal(actual$visible, c(TRUE, FALSE, NA))
  expect_type(actual$comment, "character")
})
```
Dev loop → FAIL.

- [ ] **Step 2: Fix** — in `r/link.R`, a helper above `readLink`:

```r
# python writes logical values as True/False and a missing one as an empty field; read.csv keeps all
# three as text. A column holding nothing else goes back to TRUE/FALSE/NA; any other column is untouched.
logicalFromPython <- function(x) {
  if (!is.character(x)) {
    return(x)
  }
  values <- x[!is.na(x) & x != ""]
  if (length(values) == 0 || !all(values %in% c("True", "False"))) {
    return(x)
  }
  ifelse(x == "True", TRUE, ifelse(x == "False", FALSE, NA))
}
```
and in `readLink`, after the empty-rows check:
```r
  datapy[] <- lapply(datapy, logicalFromPython)
```

- [ ] **Step 3: Rebuild, re-measure.** Expected diff: `classes.csv` lines whose `class_in` is `logical` and `class_out` was `character` now end in `logical`; `expected.csv` unchanged. Any other class change: stop and report. All suites green.

- [ ] **Step 4: Commit**

```bash
git add r/ test/roundtrip/classes.csv
git commit -F - <<'EOF'
Read python's True and False back as logical

Python writes booleans as True/False, which read.csv leaves as text, so
every logical column came back as character. The other class changes
of the CSV bridge stay as they are and stay pinned.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 12: README

**Files:** Modify: `README.md`

- [ ] **Step 1: Add, after `## Documentation`:**

```markdown
## Build
One `Dockerfile` builds both Apps. The direction is the build argument `DIRECTION`, deliberately without a default:

    docker build --platform linux/amd64 --build-arg DIRECTION=r2python .   # move2_loc to MovingPandas
    docker build --platform linux/amd64 --build-arg DIRECTION=python2r .   # MovingPandas to move2_loc

The platform passes no build arguments. The Dockerfile of an App version is therefore this `Dockerfile` with exactly one
line changed: `ARG DIRECTION` becomes `ARG DIRECTION=r2python` or `ARG DIRECTION=python2r`. A copy without that edit
fails the build.

## Tests
- python: `docker build -f test/Dockerfile .`
- both Apps, on public images only - the R tests, the round trip R → python → R and a check that the pinned versions
  agree: `docker buildx bake -f test/docker-bake.hcl test`
- the golden CSV pairs (`test/contract/`) and the round-trip expectations (`test/roundtrip/*.csv`) were produced by the
  v2.2.0 production images; `test/contract/generate.sh` and `test/roundtrip/measure.sh` reproduce them against any two
  App images (registry access needed for the defaults).
```

- [ ] **Step 2: Replace `## Null or error handling:` by:**

```markdown
## Null or error handling:
Empty MovingPandas TrajectoryCollections are transferred to a NULL object. An appropriate error will be shown in any following R App.
Null objects from the R world will cause an error in the R to Python App.
A track with a single location cannot become a MovingPandas trajectory and is dropped by the R to Python App; the App log names every dropped track.
Movebank data are UTC. Data in another timezone are transferred as UTC instants, the timezone travels along.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -F - <<'EOF'
Document the build argument and the tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 13: Local proofs for the pull request

Nothing here is committed; the results go into the pull request description (Task 14).

- [ ] **Step 1: Rebuild both Apps on the real co-pilots** (Task 5, Step 8, now with every fix; background).

- [ ] **Step 2: Everything on the real co-pilots**

```bash
R2PY_IMAGE=link-r-python:r2python PY2R_IMAGE=link-r-python:python2r KEEP=/tmp/link-new-cases test/roundtrip/measure.sh
R2PY_IMAGE=link-r-python:r2python PY2R_IMAGE=link-r-python:python2r test/contract/generate.sh
git diff --exit-code test/
```
Expected: exit 0 — the stand-in (CI) and the real co-pilots measure alike.

- [ ] **Step 3: The new rds, read by v2.2.0** — the downstream R Apps that have not been rebuilt. Feed every new output through the v2.2.0 R → python App:

```bash
source test/images.sh
mkdir -p /tmp/link-old-read/raw
for f in /tmp/link-new-cases/*/output.rds; do
  [ -s "$f" ] && cp "$f" "/tmp/link-old-read/raw/$(basename "$(dirname "$f")")_move2loc.rds"
done
cp -R test /tmp/link-old-read/test
runInImage gitlab-registry.mpcdf.mpg.de/moveapps/apps/production-a81e3046-bc48-4fcb-8d28-4291000c77f9-move2loc-to-movingpandas:7 \
  /tmp/link-old-read '/tmp/in/test/roundtrip/r2python.sh ./start-process.sh /tmp/in/raw /tmp/out/cases' /tmp/link-old-read-out
grep -H . /tmp/link-old-read-out/cases/*/r2python.exit
```
Expected: every case `0`.

- [ ] **Step 4: DIRECTION on the real co-pilot** — Task 5, Step 9 again. Expected: both refused with the message.

- [ ] **Step 5: Draft the pull request description** in the scratchpad (not in the repository), in English: what and why (spec link), the measured v2.2.0 defects and their fixes, the proofs of Steps 2–4 and of Tasks 4 and 5, the App-version instructions (the one `ARG DIRECTION` line), and the test counts before/after (python: `Ran N tests`; R: testthat `PASS n`; round trip: cases). No "Generated with" line: the team's guidelines forbid generation signatures in pull request descriptions.

---

### Task 14: Push, pull request, first CI run — **only after Clemens says go**

- [ ] **Step 1:** Show Clemens the branch log (`git log --oneline origin/main..HEAD`) and the drafted description; wait for an explicit go.
- [ ] **Step 2:** `git push -u origin feature/port-to-moveapps-package`; open the pull request against `main` with the approved description (`gh pr create --base main`).
- [ ] **Step 3:** Watch the first run of the `app` job. If it fails with `no space left on device`, add as its first step and push again:
  ```yaml
      - name: Free disk space for the App images
        run: sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL
  ```
- [ ] **Step 4:** Read the cold run's duration from the job summary; set `timeout-minutes` of `app` to about twice that, rounded up to 10 minutes; commit (`Set the App job timeout from its first run`), push.
- [ ] **Step 5:** Stop. Merge, tag `v2.3.0` and the two App versions in the admin UI happen after review, each on its own go.
