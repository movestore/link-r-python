# CI: fresh resolution weekly, and test pull requests — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `.github/workflows/test.yml` resolve the conda environment from scratch on a weekly
schedule and on demand, and run on pull requests so fork contributions are tested.

**Architecture:** One workflow-level `env.FRESH` flag, derived from `github.event_name`, drives the
cache inputs of the single existing build step. Scheduled and dispatched runs set `no-cache: true`
*and* drop `cache-from`; push and pull-request runs keep the cache and stay fast. No new jobs, no
new steps, no new files.

**Tech Stack:** GitHub Actions, `docker/build-push-action@v6`, BuildKit GHA cache backend
(`type=gha`), conda (`condaforge/miniforge3`). Verification uses `actionlint` via Docker, `yq`, and
`gh`.

**Spec:** [`docs/superpowers/specs/2026-08-04-ci-fresh-resolution-and-pr-trigger-design.md`](../specs/2026-08-04-ci-fresh-resolution-and-pr-trigger-design.md)
**Ticket:** [movestore-groundcontrol#7](https://gitlab.com/couchbits/movestore/movestore-groundcontrol/-/work_items/7)

## Global Constraints

- Branch: `claude/work-item-7-908f21`, based on `origin/main` = `b667d21` (= tag `v2.2.0`).
- The only production file this plan changes is `.github/workflows/test.yml`. Do not touch
  `test/Dockerfile`, `python/environment.yml`, or the pins in either.
- `permissions:` stays `contents: read`. Do not widen it.
- The trigger is `pull_request`, **never** `pull_request_target`.
- Cron is `'17 4 * * 1'` — quoted, and deliberately not on the hour.
- `cache-from` expression must keep the non-empty string on the truthy side of the `&&`. The
  inverted-looking form is correct; the "natural" form is silently broken. See Task 1.
- Commit messages: imperative subject, body explains *why*, and end with
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Tasks 2–4 push to the public repo `movestore/link-r-python`. Each is outward-facing and must be
  confirmed with the user before running — do not chain them automatically.

## Sequencing constraint (read before planning your order)

GitHub only offers `workflow_dispatch` and `schedule` for a workflow file that exists **on the
default branch**. Therefore:

- The `pull_request` trigger can be verified from the PR branch (Task 2) — `pull_request` uses the
  workflow as defined in the PR.
- The `push: branches: [main]` trigger can only be verified on merge (Task 3).
- The fresh/no-cache path can only be verified **after** merge (Task 4).

Do not try to `gh workflow run` from the feature branch; it will fail with
`Workflow does not have 'workflow_dispatch' trigger` and that is expected, not a bug in the change.

## File Structure

| File | Change | Responsibility |
| --- | --- | --- |
| `.github/workflows/test.yml` | Modify (whole file rewritten) | Decides *when* the suite runs and *whether* the conda layer may come from cache |
| `docs/superpowers/specs/2026-08-04-…-design.md` | Already committed (`afd7270`) | Records the reasoning |
| `docs/superpowers/plans/2026-08-04-…md` | This file | — |

---

### Task 1: Rewrite the workflow and gate it locally

**Files:**
- Modify: `.github/workflows/test.yml` (whole file — 27 lines in, 45 out)
- Test: no test file. A workflow has no unit-testable surface; the gates are `actionlint` (schema
  and context correctness) and `yq` assertions (the specific expression that has a silent-failure
  mode). Both are commands, given verbatim below.

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: a workflow-level env var `FRESH`, a string that is exactly `"true"` on `schedule` and
  `workflow_dispatch` runs and exactly `"false"` on `push` and `pull_request` runs. Tasks 2–4
  assert against that contract and against the resulting `buildx` command line.

- [ ] **Step 1: Establish the pre-change baseline is green**

`actionlint` must pass *before* the edit, otherwise a failure afterwards is ambiguous.

```bash
docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:latest -color
```

Expected: no output, exit code 0.

- [ ] **Step 2: Write the new workflow**

Replace the entire contents of `.github/workflows/test.yml` with:

```yaml
name: test

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    # Mondays, 04:17 UTC. Off the hour on purpose: GitHub's scheduler is congested at :00 and
    # delays or silently drops runs queued there.
    - cron: '17 4 * * 1'
  # so a fresh resolution can be checked after a suspected break, instead of waiting for Monday
  workflow_dispatch:

# `true` exactly for the runs that must resolve the conda environment from scratch.
# `test/Dockerfile` resolves the environment in its own layer - correctly, it is what keeps a
# source-only change cheap - but since v2.2.0 that environment is deliberately open: only `pandas`
# carries a floor and a ceiling. So a cached layer lets this suite report green against a
# resolution nobody has re-checked, and nothing evicts it on its own, because every push's
# `cache-from` resets GitHub's seven-day idle timer.
env:
  FRESH: ${{ github.event_name == 'schedule' || github.event_name == 'workflow_dispatch' }}

jobs:
  test:
    name: Unit tests
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Docker buildx
        uses: docker/setup-buildx-action@v3

      - name: Test via build
        uses: docker/build-push-action@v6
        with:
          context: .
          file: ./test/Dockerfile
          push: false
          # `no-cache` alone ought to outrank an imported cache, but that precedence is documented
          # nowhere, and it is the one assumption this whole guard rests on - so the fresh runs
          # drop `cache-from` as well and the question stops mattering.
          no-cache: ${{ env.FRESH == 'true' }}
          # Do NOT "simplify" this to `env.FRESH == 'true' && '' || 'type=gha'`. `''` is falsy in
          # GitHub expressions, so the `||` branch would always win and both paths would quietly
          # get the cache back - reinstating the exact false green this exists to prevent.
          cache-from: ${{ env.FRESH != 'true' && 'type=gha' || '' }}
          # `ignore-error`: a pull request from a fork runs with a read-only token and cannot write
          # the Actions cache, so the export 403s. Without this the run fails at the very end,
          # after the tests have already passed. Import is unaffected - a PR may read the cache of
          # its own branch, the base branch and the default branch - so fork PRs stay warm.
          cache-to: type=gha,mode=max,ignore-error=true
```

- [ ] **Step 3: Run actionlint and verify it still passes**

This is the step that catches the two things most likely to be wrong: whether the `env` context is
actually allowed inside a step's `with:`, and whether every expression is well-typed.

```bash
docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:latest -color
```

Expected: no output, exit code 0.
If it reports `context "env" is not allowed here`, stop — the design's single-step approach is
unavailable and the fallback is two `if:`-guarded steps. Report back rather than improvising.

- [ ] **Step 4: Assert the triggers parsed as intended**

```bash
yq '.on | keys' .github/workflows/test.yml
yq '.on.push.branches' .github/workflows/test.yml
yq '.on.schedule[0].cron' .github/workflows/test.yml
```

Expected, in order:

```
- push
- pull_request
- schedule
- workflow_dispatch
```
```
- main
```
```
17 4 * * 1
```

Note: `pull_request:` with an empty value parses as `null`. That is correct YAML for "all activity
types, all branches" — do not "fix" it by giving it a body.

- [ ] **Step 5: Assert the trap expression survived verbatim**

This is the regression guard for the one line with a silent-failure mode.

```bash
yq -r '.jobs.test.steps[] | select(.name == "Test via build") | .with."cache-from"' .github/workflows/test.yml
```

Expected, character for character:

```
${{ env.FRESH != 'true' && 'type=gha' || '' }}
```

If it reads `env.FRESH == 'true' && '' || 'type=gha'`, the change is broken in the specific way the
spec warns about — both events would get `type=gha`. Rewrite it.

- [ ] **Step 6: Confirm `pull_request_target` did not sneak in**

```bash
grep -c 'pull_request_target' .github/workflows/test.yml || true
```

Expected: `0`.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/test.yml
git commit -F - <<'EOF'
Resolve the environment fresh weekly, and test pull requests

`test/Dockerfile` resolves conda in its own layer, and since v2.2.0 that
environment is open by design - only `pandas` is pinned. So a cached layer let
the suite pass against a resolution nobody had re-checked, and nothing evicted
it: every push's `cache-from` reset GitHub's seven-day idle timer. Scheduled
and dispatched runs now build with `no-cache` and without `cache-from`, then
publish the fresh result, which also caps how stale an ordinary run can be.

Pull requests were not tested at all. For a repo meant to be copied, a fork PR
is the likelier origin of a change than a branch here, so `pull_request` is now
a trigger and `cache-to` tolerates the 403 a fork's read-only token earns.

`push` narrows to `main` so a branch with an open PR stops building twice.

Refs couchbits/movestore/movestore-groundcontrol#7

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 2: Verify the `pull_request` trigger against real GitHub

**⚠️ Outward-facing — confirm with the user before Step 1.** This pushes a branch to the public
repo `movestore/link-r-python` and opens a pull request.

**Files:** none changed. This task only observes.

**Interfaces:**
- Consumes: `FRESH` from Task 1, expected `"false"` on this event.
- Produces: evidence that the PR path is green and that `cache-to` does not fail a run.

- [ ] **Step 1: Push the branch**

```bash
git push -u origin claude/work-item-7-908f21
```

Expected: branch created. No workflow run starts — `push` is scoped to `main` now, and that
silence is itself the first confirmation that Task 1 landed correctly.

- [ ] **Step 2: Confirm the push did NOT trigger a run**

```bash
gh run list --branch claude/work-item-7-908f21 --limit 5
```

Expected: no run with event `push`. If a push run appears, `on.push.branches` is wrong.

- [ ] **Step 3: Open the pull request**

```bash
gh pr create --repo movestore/link-r-python --base main \
  --title 'CI: resolve the environment fresh weekly, and test pull requests' \
  --body 'Closes the CI half of couchbits/movestore/movestore-groundcontrol#7.

Since `v2.2.0` the conda environment is open by design - only `pandas` carries a floor and a
ceiling. `test/Dockerfile` resolves it in its own layer, so while that layer came from the Actions
cache the suite reported green against a resolution nobody had re-checked. Nothing evicted it
either: the cache drops entries idle for seven days, and every push refreshed the timer.

Scheduled (Mondays 04:17 UTC) and manually dispatched runs now build with `no-cache` and without
`cache-from`, then publish the fresh resolution - so ordinary runs test an environment at most a
week old rather than an arbitrarily old one.

Separately, the workflow did not trigger on `pull_request`, so fork contributions never ran.
It does now, with `ignore-error=true` on the cache export because a fork'"'"'s read-only token
cannot write the Actions cache.

Design notes: `docs/superpowers/specs/2026-08-04-ci-fresh-resolution-and-pr-trigger-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)'
```

- [ ] **Step 4: Watch the run and confirm it is green**

```bash
gh run watch "$(gh run list --branch claude/work-item-7-908f21 --event pull_request --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

Expected: exit 0. A run exists at all — that is the fix for problem 2 in the ticket.

- [ ] **Step 5: Confirm this run used the cache (i.e. `FRESH` was false)**

```bash
gh run view "$(gh run list --branch claude/work-item-7-908f21 --event pull_request --limit 1 --json databaseId --jq '.[0].databaseId')" --log | grep -E 'buildx build|--no-cache|--cache-from' | head -20
```

Expected: the buildx invocation contains `--cache-from type=gha` and does **not** contain
`--no-cache`. This is the assertion that `FRESH` resolved to `"false"` — read from the real
expression engine, not from a local re-implementation of it.

- [ ] **Step 6: Confirm the cache export did not fail the run**

```bash
gh run view "$(gh run list --branch claude/work-item-7-908f21 --event pull_request --limit 1 --json databaseId --jq '.[0].databaseId')" --log | grep -iE 'cache export|ignore-error|403' | head -20
```

Expected: either nothing, or a non-fatal warning. A same-repo PR *can* write the cache, so a 403 is
not expected here; this step establishes the baseline for the fork case, which cannot be tested
without an actual fork. Record what you see.

- [ ] **Step 7: No commit.** This task changes no files.

---

### Task 3: Merge, and verify the `push: branches: [main]` trigger

**⚠️ Outward-facing — confirm with the user before Step 1.** This merges to the default branch of
a public repo.

**Files:** none changed.

- [ ] **Step 1: Merge the pull request**

```bash
gh pr merge --repo movestore/link-r-python --merge --delete-branch=false
```

Use `--merge`, not `--squash`: every previous change landed here as a merge commit (#6, #8, #9,
#10, #12) and the plan should not silently change the repo's history style.

- [ ] **Step 2: Confirm the merge triggered a run on main**

```bash
gh run list --repo movestore/link-r-python --branch main --event push --limit 3
```

Expected: a new run, event `push`. This confirms narrowing `push` to `main` did not disable it.

- [ ] **Step 3: Confirm it is green**

```bash
gh run watch "$(gh run list --repo movestore/link-r-python --branch main --event push --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

Expected: exit 0.

- [ ] **Step 4: No commit.**

---

### Task 4: Verify the fresh path actually rebuilds the conda layer

**⚠️ Outward-facing — confirm with the user before Step 1.** Only possible after Task 3, because
`workflow_dispatch` requires the file on the default branch.

This is the task that proves the ticket is actually fixed. Everything before it proves the
plumbing; this proves the water runs.

**Files:** none changed.

**Interfaces:**
- Consumes: `FRESH` from Task 1, expected `"true"` on this event.

- [ ] **Step 1: Confirm the workflow is now dispatchable**

```bash
gh workflow list --repo movestore/link-r-python
```

Expected: `test` is listed. If it is not, the file did not reach `main`.

- [ ] **Step 2: Dispatch a run on main**

```bash
gh workflow run test --repo movestore/link-r-python --ref main
```

- [ ] **Step 3: Wait for it and capture the id**

```bash
sleep 10
RUN_ID="$(gh run list --repo movestore/link-r-python --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId')"
echo "$RUN_ID"
gh run watch "$RUN_ID" --exit-status
```

Expected: exit 0. If it **fails**, that is not necessarily a defect in this change — a fresh
resolution genuinely breaking is the exact signal the ticket asked for. Read the failure before
concluding anything, and report which of the two it is.

- [ ] **Step 4: Assert the fresh flags reached buildx**

```bash
gh run view "$RUN_ID" --repo movestore/link-r-python --log | grep -E 'buildx build' | head -5
```

Expected: the command line contains `--no-cache` and contains **no** `--cache-from`. Both halves
matter — `--no-cache` is the intent, the absent `--cache-from` is the belt-and-braces the spec
argued for.

- [ ] **Step 5: Assert the conda layer was genuinely rebuilt**

```bash
gh run view "$RUN_ID" --repo movestore/link-r-python --log | grep -E 'conda env create|CACHED' | head -20
```

Expected: the `RUN conda env create` step appears **without** a `CACHED` marker, and takes minutes
rather than seconds. This is the end-to-end proof: a fresh resolution really happened. If it shows
`CACHED`, the change does not fix the ticket, no matter how correct the YAML looks.

- [ ] **Step 6: Confirm the fresh result was published to the cache**

```bash
gh run view "$RUN_ID" --repo movestore/link-r-python --log | grep -iE 'exporting cache|importing cache' | head -10
```

Expected: an "exporting cache" section. This is what caps the staleness of subsequent runs at
roughly a week.

- [ ] **Step 7: No commit.**

---

### Task 5: Report back on the ticket

**⚠️ Outward-facing — confirm with the user before running.** Posts to GitLab.

- [ ] **Step 1: Comment on the work item with the evidence and the limitation**

```bash
glab api --method POST \
  "projects/couchbits%2Fmovestore%2Fmovestore-groundcontrol/issues/7/notes" \
  --field 'body=Umgesetzt in `movestore/link-r-python` auf `main`.

- Wöchentlich montags 04:17 UTC plus `workflow_dispatch`: Build mit `no-cache` **und** ohne
  `cache-from`, danach wird die frische Auflösung in den Cache geschrieben - damit testet auch ein
  gewöhnlicher Push eine Umgebung, die höchstens eine Woche alt ist.
- `pull_request` ist jetzt Trigger; `cache-to` hat `ignore-error=true`, weil der Read-only-Token
  eines Forks den Actions-Cache nicht schreiben darf und der Export sonst am Ende 403 wirft.
- `push` ist auf `main` eingegrenzt, sonst baut ein Branch mit offenem PR jedes Mal doppelt.

Nachweis: der dispatchte Lauf baut `conda env create` ohne `CACHED`-Marker neu.

Bekannte Einschränkung, die die Prämisse des Tickets teilweise aushebelt: GitHub deaktiviert
`schedule:`-Trigger in Repos ohne Commits seit 60 Tagen. Der wöchentliche Kanarienvogel verstummt
dann lautlos - kein rotes Build, sondern gar kein Signal. Innerhalb von Actions gibt es dafür keine
saubere Lösung; das bräuchte einen externen Ping. Ebenso gehen Fehlermeldungen geplanter Läufe nur
an die Person, die die Cron-Zeile zuletzt geändert hat.'
```

- [ ] **Step 2: Ask the user whether to close the issue or leave it open** for the 60-day
  limitation follow-up. Do not close it unilaterally.

---

## Addendum — scope extended after Task 2

Task 2 came back green but the log showed two things worth acting on, so the following were folded
into the same pull request rather than deferred. The spec section *Carried in the same change*
records the reasoning; this note exists so the plan is not a misleading record of what shipped.

- Action majors bumped: `actions/checkout` v4 → v7, `docker/setup-buildx-action` v3 → v4,
  `docker/build-push-action` v6 → v7 (every run warned about the Node 20 runtime).
- `.github/dependabot.yml` added, `github-actions` only, grouped into one pull request.
- `timeout-minutes: 30` on the job.
- Spec updated with the finding that the *test* layer caches too, not only the conda layer — so a
  green check on an unchanged tree executes no tests at all.

The verification steps in Tasks 3 and 4 are unchanged and still apply. Task 4 Step 5 gains a second
meaning: it now also confirms the bumped actions work on a real build.

## Self-Review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| Triggers (`push`→main, `pull_request`, `schedule`, `workflow_dispatch`) | 1 (Step 2), verified 2 (Step 2), 3 (Step 2), 4 (Step 1) |
| `env.FRESH` derived from event | 1 (Step 2), verified 2 (Step 5), 4 (Step 4) |
| `cache-from` dropped on fresh runs | 1 (Step 2), verified 4 (Step 4) |
| Inverted ternary, with the trap documented | 1 (Steps 2, 5) |
| `ignore-error=true` for fork PRs | 1 (Step 2), verified 2 (Step 6) |
| Weekly run rewrites the cache | 1 (Step 2), verified 4 (Step 6) |
| `permissions` unchanged, no `pull_request_target` | 1 (Step 2, Step 6) |
| Out of scope: no `concurrency`, no pin changes | Global Constraints |
| Known limitation: 60-day schedule disablement | 5 (Step 1) |

No spec requirement is unimplemented.

**Placeholder scan:** none. Every command is literal and every expected output is stated.

**Type consistency:** `FRESH` is referenced as a string compared against `'true'` in all three
places it appears (`no-cache`, `cache-from`, and both verification tasks). The `env.FRESH != 'true'`
in `cache-from` is an intentional inversion, not an inconsistency — Task 1 Step 5 pins it.

**Known risk the plan cannot eliminate:** the true fork-PR path (read-only token → cache-export
403) is not exercised anywhere, because that needs a PR from an actual fork. Task 2 Step 6 records
the same-repo baseline so the difference is recognisable if it ever bites. `ignore-error=true` is
the mitigation and it is documented; this is accepted, not overlooked.
