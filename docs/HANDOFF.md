# Handoff: state of expert-witness 1.0.0 (2026-09-30, after session 3)

Read this first when you pick the project up in a new session.

## Where the work is

- Branch `feat/v1`, PR #1 (JMcordobamendez/expert-witness), marked ready for
  review; version 1.0.0. `main` has only the initial commit. Nothing is
  merged: Josemi does the merge. Do not merge.
- If your session is assigned a different branch name, create it from
  `origin/feat/v1` (`git fetch origin feat/v1 && git checkout -B <branch>
  origin/feat/v1`); otherwise keep working on `feat/v1` so PR #1 stays current.
- Session 3 (Opus judge, four new cases, witness evidence fix) is on branch
  `claude/fix-fixture-docstring-qulkpg`, based on `feat/v1` and not yet in
  PR #1 or any PR. Josemi decides whether it goes into PR #1 or a new PR.
- Josemi (the owner) writes in Spanish. Summaries for him go on PR #1 in
  Spanish; repo docs are in English.

## Documents, in order of authority

1. `docs/specs/2026-09-30-expert-witness-design.md`: the design. Binding.
2. `docs/plans/2026-09-30-expert-witness.md`: the implementation plan
   (Tasks 1 to 6, all done).
3. `docs/baseline.md`: no-plugin baseline and the recorded risks (R1 to R7).
4. `docs/results.md`: every eval run, every grader change with its trace
   evidence, both review rounds, and the deviations from the plan.
5. `docs/eval-runs/2026-09-30-summary.json`: per-run scores, costs and failed
   graders for every run since `1ad1025`, keyed by case and commit (the raw `--json` output and the traces
   lived in `/tmp` and are gone; `docs/.results*.json` are gitignored).

## Standing rules

- Evals run **without Bash**. Never add Bash to a case's `allowed_tools` or to
  `--allow-tools` (the sandbox backend needs socat, which Josemi's machine
  lacks; R1).
- Every eval run passes `--allow-tools Write Edit` (R7); without it Write and
  Edit do not exist in the run and the report and `no-edits` graders are
  vacuous.
- Graders are never softened to make a case pass. Change one only when a trace
  proves it wrong, record the trace evidence in `docs/results.md`, and prefer
  making it stricter.
- Pure markdown plugin: no code, no build. `claude plugin validate --strict .`
  must pass before each push.
- Commits end with the session's attribution lines.

- LLM graders are judged by Opus (`--judge-model opus`). The Haiku default
  passed paraphrased evidence as "a verbatim quote" in every run before
  session 3.

Full suite (13 cases, about 32 minutes, about $46 with the Opus judge):

```
claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp \
  --allow-tools Write Edit --judge-model opus --json docs/.results.json
```

`--case` takes a glob without braces; to pick several cases use `--tag`.

One case: add `--case <name>`. After a run, remove the kept temp dirs with
`chmod -R u+rwX /tmp/claude-eval-* && rm -rf /tmp/claude-eval-*` (never run
git inside them).

## Current scores (mean of 3 runs per arm, Opus judge)

| Case | With | Without | With-plugin runs passed | Measured at |
|---|---|---|---|---|
| clean-control | 1.000 | 0.250 | 3 of 3 | `2210955` |
| code-offbyone | 1.000 | 0.750 | 3 of 3 | `2210955` |
| document-report | 1.000 | 0.833 | 3 of 3 | `efc8e16` |
| document-spanish | 1.000 | 0.833 | 3 of 3 | `efc8e16` |
| failure-anchored | 1.000 | 0.733 | 3 of 3 | `efc8e16` |
| failure-anchored-weak | 1.000 | 0.800 | 3 of 3 | `efc8e16` |
| failure-startup | 1.000 | 0.733 | 3 of 3 | `efc8e16` |
| plan-contradiction | 1.000 | 0.750 | 3 of 3 | `efc8e16` |
| plan-theory | 0.933 | 0.600 | 2 of 3 | `efc8e16` |
| quick-look | 1.000 | 1.000 | 3 of 3 | `efc8e16` |
| witness-change | 1.000 | 0.000 | 3 of 3 | `efc8e16` |
| witness-contract | 1.000 | 0.125 | 3 of 3 | `2210955` |
| witness-missing | 1.000 | 0.000 | 3 of 3 | `efc8e16` |

`2210955` changed only the witness agent's evidence rule; see
`docs/results.md`, "Session 3". witness-change, witness-contract and
witness-missing deltas are not like-for-like.

Eval spend so far: $156.03 ($17.24 in session 1, $68.49 in session 2,
$70.30 in session 3).

## Standing lesson

Step 1 (the no-shell run directory) broke every skill case twice when its
wording changed without a rerun. The harness keeps a `.git` in the home
directory above the working directory. Any change to step 1 needs a rerun of
at least one code case and one document case.

## Open items, suggested order

1. **Measure with a shell.** Every number is from runs without Bash (R1:
   socat missing on Josemi's machine). The real path (git snapshots,
   witnesses running tests) is unmeasured; a CI runner or a machine with socat
   could run the suite with `--allow-tools Bash`.
2. **Triggering boundary.** quick-look covers one request the skill must not
   take; more (a one-line fix, a question about code) would map the boundary.
3. **Paths no eval exercises:** the insufficient mark (hook deleting two
   reports), no witness answering, disputes, launching unasked.
4. **Sample size.** Three runs per arm; run `--runs 5` on any case before
   drawing conclusions from one flaky run (plan-theory was 2 of 3 once).
5. **Known trade-off in step 1:** without a shell, in a subdirectory of the
   user's repo, a document review that does not name the repo can put the run
   directory inside it.
6. **Anchoring that changes the outcome.** In both failure-anchored cases the
   session alone dropped its wrong theory; a case with genuinely ambiguous
   evidence would test whether independence changes the diagnosis.
