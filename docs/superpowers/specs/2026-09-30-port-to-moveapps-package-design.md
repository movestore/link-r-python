# Port the translator Apps to the `moveapps` R package, and put both halves under test

Date: 2026-09-30
Ticket: [Trello 1402](https://trello.com/c/9sVeyETS) — follow-up of the python co-pilot v3.1.0
runbook ([Trello 1401](https://trello.com/c/Wm20TyGx))
Touches: `Dockerfile`, `r2python.sh`, `python2r.sh`, `r/`, `python/tests/`, `test/`,
`.github/workflows/test.yml`, `README.md`

## Problem

The two translator Apps — `move2_loc to MovingPandas` (v7) and `MovingPandas to move2_loc` (v6),
both on tag `v2.2.0` — are pinned to the **old** R co-pilot,
`co-pilot-v3-r:sdk-v3.2.0_geospatial-4.3.2_3649` (R 4.3.2), and cannot follow the R upgrade:

- `r/csv_2_rds.R` and `r/rds_2_csv.R` `source()` the old SDK's files
  (`src/common/logger.R`, `src/common/runtime_configuration.R`, `src/io/app_files.R`,
  `src/io/io_handler.R`, `src/io/rds.R`).
- The `Dockerfile` moves the co-pilot's `src/` into `r/` and overwrites `src/io/rds.R` with a copy
  that drops the `move1` dependency.
- Since R co-pilot `v4.0.0` the SDK is the R package `moveapps` and there is no `src/`. With
  `co-pilot-r:v4.0.0_sdk-v1.0.3_geospatial-4.6.1_4674` the build fails at `RUN mv ../src .`.

Three further problems surfaced while scoping this:

- **The R side has no tests at all**, and the CSV pair that carries the data between the two
  languages (`meta.csv`, `link.csv`) is specified nowhere. The python side has ten tests, mostly
  timezones and gzip.
- **The App `Dockerfile` is never built by anything but the platform.** The repository's copy has
  both `start-process.sh` lines commented out, and each App version carries a hand-edited copy. The
  break above would have been invisible until someone built an App version.
- **Its conda is unpinned and unlike every python App.** It installs Miniforge from
  `releases/latest` at build time and activates via `conda init`, `.profile` and a login shell. The
  python co-pilot takes conda from `condaforge/miniforge3:26.7.2-0` and starts with `conda run`.
  `test/Dockerfile` uses a third version, `26.3.2-3`.

## Context, measured

**Production Dockerfiles** (prod snapshot, `app_versions.dockerfile`). `move2_loc to MovingPandas`
v7 equals v6, `MovingPandas to move2_loc` v6 equals v5. Against the repository `Dockerfile` they
differ only in legacy `ENV key value` syntax, one comment, and the direction-specific lines
(`r2python.sh` + `csv_2_pickle.py` + `transform_to_pickle.py` + `rds_2_csv.R`, or the mirror
image). Nothing lives in production that the repository lacks.

**A current python App** (`Stationary Tags` v6, the generated Dockerfile shared by most v3.1.0
rebuilds):

```dockerfile
FROM registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v1-python:v3.1.0
COPY --chown=$UID:$GID environment.yml $PROJECT_DIR/env.yml
RUN conda env create --prefix $ENV_PREFIX --file $PROJECT_DIR/env.yml && \
    conda clean --all --yes
```

The co-pilot is `FROM condaforge/miniforge3:26.7.2-0` (Ubuntu 24.04, `/opt/conda` owned by root,
`PATH=/opt/conda/bin:…`, conda 26.7.2, user `moveapps`) and starts the App with
`conda run --no-capture-output --prefix $ENV_PREFIX python3 sdk.py`.

**A current R App** installs its dependencies unpinned into the co-pilot's own renv project
(`RUN R -e 'remotes::install_version("move2")'` …) and finishes with `RUN R -e 'renv::snapshot()'`.
The translators deliberately do **not** follow this: platform R Apps float because renv is not
imposed on R developers. That reason does not apply here, and a pinned lock means the tests below
exercise exactly the versions that ship.

**The R co-pilot** (`co-pilot-v1/co-pilot-r/r/Dockerfile` in groundcontrol) is
`rocker/geospatial@sha256:4cee92a576e26c31546860eb252290f8f259e8236d49600d6bee695dfb96cae5`
(4.6.1) plus JRE, `libcurl4-openssl-dev`, `cmake`, user `moveapps` (uid 1001, group `staff`),
`HOME=/home/moveapps`, workdir `/home/moveapps/co-pilot-r`, `RENV_PATHS_CACHE=$HOME/.cache/R/renv`,
`RENV_CONFIG_REPOS_OVERRIDE=https://cloud.r-project.org`, `RENV_CONFIG_SANDBOX_ENABLED=FALSE`, and a
renv project holding `moveapps` 1.0.3 (GitHub `movestore/moveapps-sdk-r-package`). The hangar
inspection reads `/home/moveapps/co-pilot-r/renv.lock`. The image lives in a **private** GitLab
registry: GitHub Actions cannot pull it.

**`moveapps` 1.0.3** exports every function the translators use under the same name
(`readInput`, `storeResult`, `storeToFile`, `sourceFile`, `outputFile`, `errorFile`, `logger.*`).
Its `readRdsInput` is line for line the repository's patched `r/src/io/rds.R` — no `move1`. The
patch has no reason to exist any more.

**The platform build** runs
`/kaniko/executor --cache=true --dockerfile=/build/Dockerfile --context=dir:///build --destination=…`
— no `--build-arg`. groundcontrol does not parse the `FROM` line of stored Dockerfiles.

**Test data.** Profiled in R 4.6.1:

| | `r/data/raw` today | `Template_R_Function_App@e00af0d` (2026-09-28) |
|---|---|---|
| observations | input1–4: 3243 / 98285 / 3169 / 7770 rows | identical |
| event columns | 23–37 | 11–21 — the current Movebank cut |
| track id | `individual_name_deployment_id` | mostly `individual_local_identifier` |
| column types | character, factor, ordered, integer, integer64, logical, numeric, POSIXct, Date, units, sfc | the same families |
| list columns | only in `input_move2loc_List.rds` | none |
| timezone | UTC throughout | UTC throughout |
| edge cases | a midnight fix (input1), 75 sub-second fixes (input2), extra sfc event columns (input3) | the same |

Movebank's principle is "everything in UTC", so a non-UTC `tzone` is an edge case — but a
reachable one: nothing stops a user from converting.

**The round trip of `v2.2.0`, measured** on the production images themselves
(`…-move2loc-to-movingpandas:7`, `…-movingpandas-to-move2loc:6`), every Template input plus the
List file, R → python → R through each image's own `start-process.sh`:

- intact: row and track count (except below), every instant (except below), coordinates within
  5e-9, crs, track ids;
- the time column comes back as `timestamp_utc` in UTC, next to an added `timestamp_tz`; the
  original `timestamp` survives as a character column — by design of the python side;
- attribute classes change in ways the CSV bridge implies: factor → character/integer,
  integer64 → integer/numeric, units → integer/numeric, Date and POSIXct attributes →
  character, sfc → WKT character;
- the defects listed under [Defects](#defects).

## Goals

1. Both translators build `FROM` the current R co-pilot and run on `moveapps`, R 4.6.1, with
   output equivalent to `v2.2.0`.
2. One `Dockerfile` builds both Apps; the two App versions differ in exactly one line.
3. The Python side uses the same conda as the python Apps.
4. The R side, the python side and the CSV contract between them are tested; the real App images
   are built and exercised in CI on every change.
5. Defects the new tests uncover are fixed in this change, one commit each.

## Non-goals

- The pickle format and the python dependency resolution (`python/environment.yml`). Both were
  settled by the gzip rollout (`v2.2.0`). A conda lock would be the python counterpart of
  `r/renv.lock`; it stays a follow-up question.
- The move1 translators (`legacy/move1`).
- groundcontrol. The only groundcontrol-side follow-up is documentation, see the end.

## Design

### R code

- **New `r/link.R`** — pure functions, camelCase like the SDK:
  - `linkMeta(data)` → the `meta.csv` data.frame (`crs`, `tzone`, `timeColName`,
    `trackIdColName`).
  - `linkTable(data)` → the `link.csv` data.frame: collapse list columns, track attributes to
    event attributes, `coords_x`/`coords_y`, geometry dropped, sfc columns as WKT, the time
    column formatted `%Y-%m-%d %H:%M:%OS3`.
  - `writeLink(data, bufferFile, metaFile)` → writes `meta.csv`, then `link.csv`, in the order and
    with the `write.csv` calls of `v2.2.0`.
  - `readLink(bufferFile, metaFile)` → a `move2` object, or `NULL` for an empty buffer.
- **`r/rds_2_csv.R` and `r/csv_2_rds.R`** stay the entry points `start-process.sh` calls, reduced
  to: `library("moveapps")`, `moveapps::logger.init()`, `source("link.R")`, and the `tryCatch`
  around `moveapps::readInput` / `moveapps::storeResult` / `moveapps::storeToFile`. The logic moves,
  it does not change (proved by the goldens, below).
- **`r/src/` is deleted.**
- **`r/renv.lock` and `r/renv/activate.R`** are regenerated inside the new co-pilot image:
  R 4.6.1, renv 1.2.4, `moveapps` 1.0.3 from GitHub, plus `move2`, `sf`, `dplyr`, `vctrs`,
  `purrr`, `rlang`. The translator keeps its own renv project in `r/`.
- **`r/.renvignore`** excludes `tests/`, so testthat never enters the App's lock — and therefore
  never the hangar inspection.

### App `Dockerfile`

```dockerfile
ARG BASE=registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-r:v4.0.0_sdk-v1.0.3_geospatial-4.6.1_4674
# the very conda the python co-pilot ships
ARG CONDA=registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v1-python:v3.1.0
FROM ${CONDA} AS conda
FROM ${BASE}
COPY --from=conda /opt/conda /opt/conda
ENV PATH=/opt/conda/bin:$PATH

# python: exactly as the python Apps
#   conda env create --prefix $ENV_PREFIX --file … && conda clean --all --yes
# r: the translator's own renv project in r/
#   restore the lock; drop the co-pilot's unused project and entry point
#   (../renv ../renv.lock ../.Rprofile ../RFunction.R ../app.R); cp renv.lock ../ for the hangar
#   inspection
# the scripts of both directions, as today

ARG DIRECTION
RUN case "$DIRECTION" in r2python|python2r) ;; *) echo "DIRECTION must be r2python or python2r" >&2; exit 1 ;; esac
COPY --chown=$UID:$GID ${DIRECTION}.sh start-process.sh
```

- **`BASE`** exists for CI only. Its default is the private co-pilot, so the platform, which
  passes no build arguments, builds exactly what it builds today.
- **`CONDA`** likewise. Its default is the python co-pilot `v3.1.0`, which is
  `FROM condaforge/miniforge3:26.7.2-0` and leaves `/opt/conda` untouched. conda is taken from
  there rather than from Docker Hub because no App version on the platform has ever pulled from
  outside the couchbits GitLab registry: kaniko holds credentials for gitlab.com and the MPCDF
  GitLab only, and no mirror. CI, which cannot pull the python co-pilot, passes
  `CONDA=condaforge/miniforge3:26.7.2-0`.
- **`DIRECTION` has no default, on purpose.** With one, forgetting to change it would silently
  build the wrong App; without one, the build fails and says why.
- **`DIRECTION` is declared last, on purpose.** A changed ARG value is a cache miss for every
  following `RUN`; declared at the top, the two directions would not share the conda and renv
  layers. The price: a missing `DIRECTION` fails after the long steps rather than before.
- **Removed:** the Miniforge download from `releases/latest`, `conda init`, the `.profile` line,
  `MINICONDA_VERSION`, `CONDA_DIR`, and the `mv ../src` / `rm` / `COPY r/src/io/rds.R` block
  together with its `USER root:root` switch.
- **On the platform** the App version's Dockerfile is the repository's `Dockerfile` with one line
  changed: `ARG DIRECTION=r2python` or `ARG DIRECTION=python2r`.

### Start scripts

`r2python.sh` and `python2r.sh` call python via
`conda run --no-capture-output --prefix "$ENV_PREFIX" python …` — the python co-pilot's own form;
without `--no-capture-output` conda swallows the output, including a failure. The shebang drops
`--login`, which existed only for `conda activate`.

### Test data and fixtures

- **`r/data/raw/`** is replaced by the eight `move2loc` files of
  `movestore/Template_R_Function_App@e00af0d779f9756c40161bffd8d6f0a5ebc77ced`.
  `input_move2loc_List.rds` stays — the only source of list columns. The `telemetrylist` files are
  not a translator input type and are left out. The old files remain in history.
- **The non-UTC cases are derived at run time**, not stored as further binaries: input1 with
  `tzone` set to `Europe/Berlin` (it has no fix in the repeated hour of 2021-10-31), and a
  two-fix track at 00:30 and 01:30 UTC on 2021-10-31 in `Europe/Berlin` — both `02:30` local.
- **Golden files** in `test/contract/<case>/`:
  - `input.rds` — a few rows cut from `r/data/raw` at fixed indices;
  - `meta.csv`, `link.csv` — the R → python direction;
  - `py/meta.csv`, `py/link.csv` — the python → R direction.

  Cases: LatLon with three tracks, Mollweide including the midnight fix, sub-second fixes, Argos
  sfc event columns, list columns, non-UTC outside a DST switch.

  **The goldens are produced once, by `v2.2.0`** — by the production images themselves, pulled
  from the platform registry, so the reference is literally what runs in production. That makes
  them the proof that the port changes nothing, carried into CI permanently. From then on a change
  to a golden is a deliberate contract change and shows as such in the diff. The generator is
  committed alongside.
- **The round-trip expectations** are measured the same way, on all inputs, and pinned in two
  files the round-trip test reads: `test/roundtrip/expected.csv` (per input: rows and tracks out,
  largest time deviation, output time column and `tzone`) and `test/roundtrip/classes.csv` (per
  input and column: class in, class out). A defect fix changes the lines it corrects, visibly.

### Tests

New tests mark their blocks `# arrange` / `# act` / `# assert`; existing tests keep their words.

**R** — testthat, `r/tests/testthat/`:
- `linkMeta`, `linkTable` and `readLink` on their own: crs (`EPSG:4326`, `ESRI:54009`), tzone,
  column names; list columns collapsed when equal per track and pasted when not; track attributes
  present per event; sfc as WKT; milliseconds kept at midnight, at `.000` and below the second;
  times parsed in `tzone`; rows ordered by track and time; an empty buffer.
- Contract: the new code on `input.rds` reproduces `meta.csv` and `link.csv` **byte for byte**;
  `readLink` on `py/*.csv` yields the expected `move2` (rows, tracks, times, crs, columns).

**Python** — `python/tests/`:
- New coverage: `write_meta_csv`, the columns of the written `link.csv`, `read_meta_csv`,
  `create_moving_pandas` (crs, number of trajectories).
- `test_contract.py`: golden `*.csv` → pickle → `*.csv` equals `py/*.csv`.

**Round trip** — CI, inside the real App images: for every `r/data/raw/*move2loc*.rds` plus the
non-UTC cases, the r2python image's `start-process.sh` writes a pickle, the python2r image's
`start-process.sh` turns it back into an rds. Asserted against `expected.csv`: rows and tracks out,
the largest time deviation, output time column and `tzone`; strictly: track per row, coordinates
within 1e-8, crs, every input column name present. Classes are asserted against `classes.csv`.
Plus one python-born case: an empty `TrajectoryCollection` through the python2r image.

**Local only, once** — the old image is private, so these land in the pull request description:
- old against new on every input, outputs compared;
- the new rds read by the old image (R 4.3.2, old `move2`) — the downstream R Apps that have not
  been rebuilt;
- both App images build; a build without, and one with an invalid, `DIRECTION` fails.

### CI

`.github/workflows/test.yml`:

- **`test` / "Unit tests"** — the existing job, same id and name so a required status check keeps
  matching. `test/Dockerfile` moves to `condaforge/miniforge3:26.7.2-0` and runs all python tests,
  the contract tests included.
- **`app`** — new, via `docker buildx bake` (`test/docker-bake.hcl`):
  1. `co-pilot-r` — `test/co-pilot-r.Dockerfile`: a public stand-in for the private co-pilot. Same
     rocker digest, `cmake`, user `moveapps`, `HOME`/`UID`/`GID`, `/home/moveapps/co-pilot-r`, the
     renv environment variables, renv. No Java part, no co-pilot renv project — the translator
     brings `moveapps` through its own lock.
  2. `app-r2python`, `app-python2r` — the **real** `Dockerfile`, `BASE=co-pilot-r` through a bake
     context `target:co-pilot-r`, and the respective `DIRECTION`.
  3. `test` — `test/app-test.Dockerfile` on top of both App images: the R unit tests (testthat
     installed at a pinned version, outside the lock), the round trip, the coherence check. A
     failing test fails the build — the pattern the python job already uses.
  4. The build without and with an invalid `DIRECTION` **must** fail. With the cache warm this
     costs the last layers only.
- **Coherence check** — the pins nobody else compares. All must agree:
  - the stand-in's R version = `r/renv.lock` `.R.Version` = `geospatial-X` in the `BASE` default;
  - `moveapps` in `r/renv.lock` = `sdk-vX` in the `BASE` default;
  - the Miniforge tag CI passes as `CONDA` = the one in `test/Dockerfile`.

  Two pairs cannot be checked, because the co-pilots are private: the stand-in's rocker digest
  against the R co-pilot's, and the Miniforge tag against the python co-pilot's base. Each is
  stated where it is pinned.
- **P3M binaries, in the stand-in only**:
  `RENV_CONFIG_REPOS_OVERRIDE=https://p3m.dev/cran/__linux__/noble/latest`. The versions stay the
  lock's; only the build path differs from the platform, which compiles from source. Where P3M
  has no binary for a pinned version renv falls back to source, which is why `cmake` is there.
- **Cache** `type=gha`, one scope per target. **Fresh runs** (weekly, `workflow_dispatch`) drop the
  cache for both jobs: the App image resolves the same open conda environment. R is pinned by
  its lock either way.
- **Timeout** for `app`: measured on the first cold run, then set with headroom. `test` keeps 30
  minutes.
- **Dependabot** stays on `github-actions`. The rocker digest and the Miniforge tag are pinned by
  hand and guarded by the coherence check.

### Defects

All measured on the `v2.2.0` production images. Fixed in this change, each in its own commit, each
with the test that pins the corrected behaviour.

1. **An empty `TrajectoryCollection` fails the python → R App.** `TransformToCsv.create_geopandas`
   raises `ValueError: No objects to concatenate`, while the README promises a NULL object. The
   same happens when every track has a single fix. Behind it, `csv_2_rds.R` would not have written
   an output for zero rows either: it calls `storeResult` only in the non-empty branch. Corrected
   behaviour: python writes an empty `link.csv` and `meta.csv`, R stores the NULL output — an
   empty file, the platform's convention, which the next R App rejects with code 10.
2. **DST ambiguity, R → python.** R writes local wall-clock times without an offset; python
   re-localises them with `tz_localize(tzone)`. Two fixes at 00:30 and 01:30 UTC on 2021-10-31 in
   `Europe/Berlin` both become `2021-10-31 02:30:00.000`, and the App fails with
   `AmbiguousTimeError` — for instants R held unambiguously. The fix transmits UTC in `link.csv`
   (`tzone` stays in `meta.csv`) and converts on the python side. The existing tests that pin the
   raise and localise wall-clock times are changed deliberately. For UTC data — all real data —
   `link.csv` stays byte-identical.
3. **Sub-second precision is lost, python → R.** python writes `…:31.123`, `readLink` parses with
   `%S` and truncates: 75 fixes of input2 come back up to 0.999 s early. The fix parses with `%OS`.
4. **Single-fix tracks vanish silently, R → python.** movingpandas cannot form a trajectory from
   one point; `input_move2loc_List` goes in with 5 rows in 4 tracks and comes back with 2 rows in
   1 track. Not fixable within the format. The fix: `TransformToPickle` logs a warning naming
   every dropped track and its row count, so the App log shows the loss. The output stays as is.
5. **logical comes back as character, python → R.** python writes `True`/`False`, which
   `read.csv` does not recognise. The fix: `readLink` turns a column holding only `True`, `False`
   and `NA` back into logical. The other class changes are inherent to the CSV bridge and stay
   pinned in `classes.csv`.

Measured and **not** a defect: a tz-aware index. movingpandas drops the timezone itself, so
`TransformToCsv.get_timezone` never sees one; its tz-aware branch is dead code and stays untouched.

The CSV pair is created and consumed inside one App, so a contract fix creates no ordering
constraint between App versions.

## Sequence and proofs

One commit per step, each green on its own:

1. Replace `r/data/raw/` with the Template set.
2. Goldens and type mapping, produced by `v2.2.0`; generator committed.
3. Python gaps and contract tests, pinning today's behaviour and green against today's code. A
   test for a defect arrives with its fix in step 7, not here.
4. R refactoring into `link.R` plus testthat — **still on the old image**: the refactoring alone
   changes nothing.
5. The port: `moveapps`, the new lock, the `Dockerfile` (`BASE`, conda from the image,
   `DIRECTION`), `conda run` in the scripts, `r/src/` removed: R 4.6.1 and the new packages change
   nothing. Steps 4 and 5 are separate proofs, so a deviation has exactly one cause.
6. CI: stand-in, bake, test target, coherence check, the `app` job.
7. Defect fixes, one commit each. Until its fix, the DST case runs in the round trip as an expected
   failure of the r2python step; the empty case joins with fix 1.
8. README: building with `--build-arg DIRECTION=…`, and the one line that differs per App.

## Delivery

Each step after an explicit go:

1. Push, pull request against `main`, in English, with the local proofs.
2. After the merge: tag `v2.3.0`. The runtime moves, the external formats do not.
3. The App versions are created by hand in the admin UI. Dockerfile: the repository's, with
   `ARG DIRECTION=r2python` or `ARG DIRECTION=python2r`. Their order does not matter: the rds and
   pickle formats are unchanged — the rds side proved by the old-image read above.
4. An A3-style workflow run on mtest1 (R → python → R).

## Risks

- **bake resolving `FROM ${BASE}` through a `target:` context** — measured locally (buildx 0.37.1,
  BuildKit 0.25.1) with stand-in images: the matrix over both directions, `COPY --from` between the
  App targets, and the refusal of an invalid `DIRECTION` all work. Not yet measured on the GitHub
  runner's builder. Fallback: a local registry as a service container.
- **The stand-in can drift from the co-pilot.** The coherence check catches a version mismatch;
  a republished rocker tag under the same R version it cannot. The digest comment and the
  groundcontrol follow-up below are the mitigation.
- **Runner disk and the Actions cache.** rocker/geospatial alone is 4.3 GB, and the Actions cache
  is capped at 10 GB per repository. Measured on the first cold run; eviction costs time, not
  correctness.
- **P3M may not carry binaries for every pinned version** — then those compile, and the cold run
  takes longer.

## Follow-ups

Not part of this change; tickets only after Clemens approves each:

- groundcontrol: list `link-r-python` in `upgrade-co-pilot-runtime/references/r.md` §5 — an R
  upgrade needs its lock re-snapshotted and the stand-in's digest moved.
- A conda lock for the python side.
