# CI: guarantee a fresh environment resolution, and test pull requests

Date: 2026-08-04
Ticket: [movestore-groundcontrol#7](https://gitlab.com/couchbits/movestore/movestore-groundcontrol/-/work_items/7)
Touches: `.github/workflows/test.yml`

## Problem

`test/Dockerfile` resolves the conda environment in its own layer, before the sources are copied:

```dockerfile
COPY python/environment.yml ./python/
RUN conda env create --prefix ${ENV_PREFIX} --file python/environment.yml && \
    conda clean --all --yes
```

That layering is correct — it is what keeps a source-only change cheap. It is also what makes the
CI result untrustworthy, because since `v2.2.0` the environment is deliberately open:

```yaml
- python
- pandas>=2.3.3,<3
- geopandas
- movingpandas
```

Only `pandas` carries a floor and a ceiling; everything else floats. So "does this still resolve,
and does it still pass?" is a question with a moving answer, and the CI only ever asks it when the
cache misses. As long as the `conda env create` layer is served from the GitHub Actions cache, the
suite runs against a resolution that may be months old and reports green.

Nothing evicts that layer on its own. The Actions cache drops entries untouched for seven days, but
every push reads it via `cache-from`, which resets the timer. In an active repo the stale layer
survives indefinitely — until `environment.yml` changes, which is exactly the moment nobody is
watching for an unrelated dependency to have moved underneath.

This is not hypothetical. During rollout an App build pulled its conda layer from the kaniko cache
and completed "successfully" against the old environment.

### It is worse than the ticket says: the test layer caches too

Confirmed empirically on the first `pull_request` run of this change
([run 30901212941](https://github.com/movestore/link-r-python/actions/runs/30901212941), 21 seconds,
green):

```
#10 [4/6] RUN conda env create --prefix /opt/link-r-python/conda --file python/environment.yml
#10 CACHED
#12 [6/6] RUN conda run ... python -m unittest python.tests.test_transform_to_pickle ...
#12 CACHED
```

The ticket describes the *resolution* going stale. But `unittest` runs in a `RUN` layer like any
other, so on an unchanged tree it is cached as well and no test executes at all. A green check
means "nothing needed rebuilding", not "the tests passed".

For a change that touches only `.github/` or `docs/` that is the correct outcome — there is nothing
to retest. And coverage of real changes is intact: touching `python/` invalidates the `COPY` layer,
touching `environment.yml` invalidates the conda layer, and in both cases the tests re-run. So this
does not call for a fix of its own.

It does, however, change what the weekly run is *for*. It is not only the one run that re-resolves
the environment; it is the one run that executes the test suite at all against an unchanged tree.
That makes it the sole periodic evidence that the App's environment still works — which is a
stronger reason to have it than the ticket claimed.

Second, separate problem: the workflow triggers on `push` only. Pull requests from forks never run.
For a template repo whose whole purpose is to be copied by external contributors, a fork PR is the
*likelier* origin of a change than a branch in this repo.

## Design

### Triggers

```yaml
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '17 4 * * 1'
  workflow_dispatch:
```

`push` is narrowed to `main`. Without that, a branch in this repo with an open PR builds twice on
every push — the same Docker build, twice the minutes, twice the cache writes. Everything in this
repo lands through a PR (#6, #8, #9, #10, #12), so branch coverage is not lost, only deduplicated.

The cron sits at `:17`, not `:00`. GitHub's scheduler is congested on the hour and delays or drops
runs queued there.

`workflow_dispatch` exists so a fresh resolution can be checked on demand — after a suspected
upstream break, or to confirm a fix — instead of waiting up to a week for the next Monday.

### One flag, derived from the event

```yaml
env:
  FRESH: ${{ github.event_name == 'schedule' || github.event_name == 'workflow_dispatch' }}
```

```yaml
          no-cache: ${{ env.FRESH == 'true' }}
          cache-from: ${{ env.FRESH != 'true' && 'type=gha' || '' }}
          cache-to: type=gha,mode=max,ignore-error=true
```

Scheduled and manually dispatched runs resolve from scratch. Pushes and pull requests keep using
the cache and stay fast.

Three decisions here are not self-evident from the diff:

**`cache-from` is dropped on fresh runs, not merely overridden by `no-cache`.** `--no-cache` ought
to take precedence over an imported cache, but that precedence is not documented either way, and it
is the single assumption the whole ticket rests on. Removing the import removes the question. The
belt is cheap; the braces are the point.

**The ternary is inverted deliberately.** The natural spelling is a trap:

```yaml
cache-from: ${{ env.FRESH == 'true' && '' || 'type=gha' }}   # WRONG
```

`''` is falsy in GitHub expressions, so `true && ''` yields `''`, the `||` branch wins, and the
result is `type=gha` on *both* paths. That failure is silent and it reintroduces precisely the
false-green this change exists to remove. Keeping the non-empty string on the truthy side is what
makes the expression work; do not "simplify" it back.

**`ignore-error=true` on the export.** A fork PR runs with a read-only token and cannot write the
Actions cache, so `cache-to` fails with a 403. Without this attribute the build dies at the very
end, after the tests have already passed — a red check for a green suite. Import is unaffected: a
PR run may read the cache of its own branch, the base branch, and the default branch, so fork PRs
still get a warm build. The attribute is documented for the `gha` backend.

The trade-off accepted: a genuine cache-export failure on `main` is now also swallowed. That is the
right way round, because a failed cache write says nothing about whether the code is correct.

### Letting the weekly run write the cache

The scheduled run keeps `cache-to`. It resolves fresh, then publishes that resolution as the new
lineage, so ordinary pushes test an environment at most seven days old rather than an arbitrarily
old one. This turns the weekly job from a pure detector into something that also bounds the
staleness of every other run.

### Unchanged

`permissions: contents: read` stays. Cache export authenticates through the Actions runtime token,
not the `permissions` block, so no widening is needed.

The trigger is `pull_request`, **not** `pull_request_target`. `pull_request` runs fork code with a
read-only token and no secrets, which is the whole reason it is safe to build arbitrary contributor
Dockerfiles. `pull_request_target` would hand that same untrusted code a writable token.

### Carried in the same change

Three things surfaced while verifying the above and are fixed here rather than deferred, because
all three are about the same thing: whether a green check can be believed.

**Action majors.** `actions/checkout` v4 → v7, `docker/setup-buildx-action` v3 → v4,
`docker/build-push-action` v6 → v7. Every run was warning that these target Node 20 and are being
force-migrated to Node 24. All three majors are substantively just that runtime switch; the one
real breaking change, `checkout` v7 refusing to check out fork code under `pull_request_target` and
`workflow_run`, cannot affect us because we use neither — and it hardens the same boundary this
design already chose.

**`.github/dependabot.yml`.** The bump above is the symptom; the absence of an update mechanism is
the cause. Three majors of drift went unnoticed until GitHub started warning. Scoped to
`github-actions` only and grouped into a single pull request. The Docker ecosystem is deliberately
left off: the App `Dockerfile` pulls from a private GitLab registry Dependabot cannot authenticate
against, so enabling it would generate recurring failures rather than updates.

**`timeout-minutes: 30`.** GitHub's default is 360. Harmless while every run was a cache hit
finishing in 21 seconds — but the weekly run now resolves conda for real, unattended, and a hung
solver would otherwise burn six hours of runner time every Monday.

## Out of scope

**No `concurrency` block.** With `push` limited to `main` the duplicate-run problem is already
solved, and `cancel-in-progress` on a build that writes cache risks interrupting an export and
leaving a partial lineage.

**No change to the pins in `environment.yml`.** The `pandas<3` ceiling has its own ticket.

**No R tests.** Worth stating plainly because it is easy to miss: there are none. `find r -iname
'*test*'` is empty, so CI covers the Python half of this translator App and nothing else. Writing
them is a project, not a rider on a CI ticket — but the gap should not be discovered by accident.

**`environment.dev.yml` is still never built.** It is kept "in step with `environment.yml`" by hand
and can rot silently. Building it weekly too would roughly double the scheduled run's cost for a
file no App ever uses at runtime.

**No failure-to-issue reporting for scheduled runs.** It is the only measure that would fully
deliver the ticket's premise — see Known limitations — but it needs `issues: write`, a
`github-script` stage and deduplication, which is a different kind of change from this one.

## Known limitations

**GitHub disables `schedule:` triggers in a repo with no commits for 60 days.** A template repo can
easily go that quiet. The canary then stops silently — the failure mode is *no signal*, not a red
build, which is the worse of the two. There is no clean fix inside Actions; it needs an external
ping or a periodic human check. Worth knowing, because the ticket's premise is "we hear it from CI
and not from an App build", and a disabled schedule quietly voids that.

**Scheduled-run failure notifications go to whoever last edited the cron line**, not to repo
watchers. If that person leaves, the alert leaves with them.

## Verification

- The workflow parses against the GitHub Actions schema.
- `FRESH` evaluates `true` for `schedule` / `workflow_dispatch` and `false` for `push` /
  `pull_request`, and `cache-from` is empty in exactly the `true` case — this is the expression
  that has a silent-failure mode, so it is checked by evaluating it, not by reading it.
- A dispatched run rebuilds the `conda env create` layer instead of reporting `CACHED`.
