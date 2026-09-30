# Handoff: state of expert-witness 1.0.0 (2026-09-30)

Read this first when you pick the project up in a new session.

## Where the work is

- Branch `feat/v1`, PR #1 (JMcordobamendez/expert-witness), marked ready for
  review; version 1.0.0. `main` has only the initial commit. Nothing is
  merged: Josemi does the merge. Do not merge.
- If your session is assigned a different branch name, create it from
  `origin/feat/v1` (`git fetch origin feat/v1 && git checkout -B <branch>
  origin/feat/v1`); otherwise keep working on `feat/v1` so PR #1 stays current.
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

Full suite (9 cases, about 19 minutes, about $26):

```
claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp \
  --allow-tools Write Edit --json docs/.results.json
```

One case: add `--case <name>`. After a run, remove the kept temp dirs with
`chmod -R u+rwX /tmp/claude-eval-* && rm -rf /tmp/claude-eval-*` (never run
git inside them).

## Current scores (mean of 3 runs per arm)

| Case | With | Without | With-plugin runs passed | Measured at |
|---|---|---|---|---|
| clean-control | 1.000 | 0.500 | 3 of 3 | `196ebd2` |
| code-offbyone | 1.000 | 0.750 | 3 of 3 | `8508aa9` |
| document-report | 1.000 | 0.833 | 3 of 3 | `8508aa9` |
| document-spanish | 1.000 | 0.833 | 3 of 3 | `8508aa9` |
| failure-startup | 1.000 | 0.800 | 3 of 3 | `196ebd2` |
| plan-contradiction | 1.000 | 0.750 | 3 of 3 | `196ebd2` |
| plan-theory | 1.000 | 0.600 | 3 of 3 | `196ebd2` |
| witness-change | 1.000 | 0.083 | 3 of 3 | `196ebd2` |
| witness-contract | 1.000 | 0.125 | 3 of 3 | `196ebd2` |

`8508aa9` changed only step 1 (run directory); see `docs/results.md`,
"Session 2". witness-change and witness-contract deltas are not like-for-like.

Eval spend so far: $85.73 ($17.24 in session 1, $68.49 in session 2). A full
suite now takes about 19 minutes and $26.

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
2. **A negative triggering case.** The description was widened to "critique
   it in detail"; no case checks that the skill stays quiet on a request it
   should not take (a quick question about a file, a one-line fix).
3. **Paths no eval exercises:** retry, missing witnesses and the insufficient
   mark, disputes, launching unasked. A helper-plugin hook like
   witness-change's could delete a witness report to exercise retry.
4. **Sample size.** Three runs per arm with a Haiku judge; run `--runs 5` on
   any case before drawing conclusions from one flaky run.
5. **Known trade-off in step 1:** without a shell, in a subdirectory of the
   user's repo, a document review that does not name the repo can put the run
   directory inside it.
