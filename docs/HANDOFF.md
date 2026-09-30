# Handoff: state of expert-witness v1 (2026-09-30)

Read this first when you pick the project up in a new session.

## Where the work is

- Branch `feat/v1`, draft PR #1 (JMcordobamendez/expert-witness). `main` has
  only the initial commit. Nothing is merged. Do not merge or mark the PR
  ready unless Josemi asks.
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
   graders for the two final runs (the raw `--json` output and the traces
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

Full suite (about 11 minutes, about $15):

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
| clean-control | 0.750 | 0.500 | 2 of 3 | `1ad1025` |
| code-offbyone | 1.000 | 0.500 | 3 of 3 | `1ad1025` |
| document-report | 0.944 | 0.833 | 2 of 3 | `7c7f2b5` |
| failure-startup | 1.000 | 0.733 | 3 of 3 | `1ad1025` |
| plan-contradiction | 1.000 | 0.750 | 3 of 3 | `1ad1025` |
| witness-contract | 1.000 | 0.125 | 3 of 3 | `1ad1025` |

Eval spend so far: $17.24.

## Open items, suggested order

1. **Fix the code-offbyone fixture docstring** (`evals/code-offbyone/fixture/window.py`
   and the copy in `evals/witness-contract/fixture/`). It contradicts itself:
   "within the last n days, today included" is n days, "exactly n days before
   today is included" is n+1. Proposed line: `"""Return the entries dated from
   n days before today through today, both ends included.` Fix the fixture,
   not the grader.
2. **Rerun the full suite** at the current head. The skill wording changed
   twice after the `1ad1025` measurement (`7c7f2b5` run-directory rule and
   `7b3b1ea` final review fixes); only document-report was re-measured, and
   only after the first of those.
3. **clean-control flakiness.** One run failed `no-invented`: the Haiku judge
   rejected a report whose confirmed findings were all minor; that report also
   used "Findings" / "Rejected findings" instead of the template's sections.
   Look at whether step 9 of `SKILL.md` needs to insist harder on the template
   headings before touching the grader.
4. **Triggering.** document-report's prompt ("critique it in detail") fired
   the skill in 2 of 3 runs. Consider the skill description wording.
5. **Paths no eval exercises** (listed in README Limitations): retry, missing
   and insufficient witnesses, disputes, launching unasked, an after snapshot
   that catches a change, non-English reports, a witness Write inside the repo.
   Adding cases is optional; each costs about $2 to $3 per 3+3 runs.
6. After the next full run: update the table in `README.md`,
   `docs/results.md`, this file and the summary JSON, then post a Spanish
   summary on PR #1.
