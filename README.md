# expert-witness

Blind multi-model review for Claude Code. Three witnesses who have never seen
your session (one each on Sonnet, Opus and Fable) review a piece of code, a
plan, a document or a failure, and the orchestrating session checks every
finding against the source before it reaches you.

## Why blind witnesses

A session that has worked on something for a while believes its own story.
When it reviews its own work, or briefs a reviewer, it passes that story on:
its guess at the cause, its checklist of where bugs must be, its reading of
the request. The review then confirms what the session already thought.

`expert-witness` cuts that link. Witnesses are ordinary subagents with no
session context. They get a brief with only the request quoted verbatim,
pointers to the material and, for a failure, observed facts. The session's
theories never go in, not even marked as unverified. Like an expert witness in
court, each gives an independent opinion and decides nothing: the session
verifies, and you overrule.

## Install

```
/plugin marketplace add JMcordobamendez/expert-witness
/plugin install expert-witness@expert-witness
```

The repo is its own marketplace. The plugin has no scripts, no dependencies,
no API keys and no external model providers.

## Use

```
/expert-witness <what to review>
```

Or just ask for an independent, blind, multi-model or detailed review, audit
or critique; for a document someone wrote, "critique it in detail" is enough.
It reviews one subject of one of four kinds:

| Kind | Example request | What witnesses look for |
|---|---|---|
| `code` | "Get me an independent review of the last commit in ./repo before I merge." | bugs, edge cases, security, effects on callers, missing tests |
| `plan` | "I've just finished ./docs/spec.md, have it reviewed before I plan." | contradictions, gaps, infeasible steps, unstated assumptions |
| `document` | "Critique ./board/report.md against ./board/sales.csv." | claims the data contradicts, conclusions that do not follow, missing information |
| `failure` | "The app won't start under the service manager; logs in ./logs. Get me an independent diagnosis." | the cause, with evidence and the cheapest check to confirm it |

Claude also launches it on its own at three moments only: right after a spec,
plan or design is written and before the next stage; after a failure has
resisted two fix attempts; and before a change that is hard to undo or touches
security. It announces the launch in one line and carries on without waiting.
It does not re-run on the same subject unless something new happened.

## How it works

1. **Run directory** outside the reviewed repo, so nothing lands in
   `git status`.
2. **Brief** (`brief.md`), identical for all three witnesses: the kind, the
   request quoted verbatim, pointers (paths, commit range, commands) rather
   than pasted content, and for a failure facts only (symptom, how to
   reproduce, errors verbatim, each thing tried and what happened). The
   session rereads it and strips anything that states or implies its own
   conclusion.
3. **Before snapshot** of what a witness could change (`git status` and
   `HEAD`, or file hashes).
4. **Dispatch**: three `expert-witness:witness` subagents in one message, on
   `sonnet`, `opus` and `fable`. Each writes a report in a fixed shape: one
   block per finding (severity, location, verbatim evidence, problem,
   proposal, confidence, what would refute it), then opinions found in the
   brief, unintended consequences, and what it could not check. "No findings"
   is an allowed answer.
5. **After snapshot**; any change a witness made is reported first.
6. **Collect**: a witness that fails or ignores the report shape is retried
   once, then reported as missing. With one witness left the run is marked
   insufficient.
7. **Cluster** findings about the same problem and record who raised each
   (S, O, F).
8. **Verify** each cluster against the real source: confirmed, does not hold
   (with the reason), or could not verify (with the reason). Three witnesses
   agreeing does not make a finding true.
9. **Report** (`report.md`, in your language): changes made by witnesses,
   diagnosis (failures), confirmed findings most severe first, disagreements,
   what does not hold, what could not be verified, missing witnesses.

Witnesses diagnose and propose; they never apply fixes. If you dispute a
verdict, one fresh witness looks at that single finding, without being told
who raised or rejected it. There are no "do you approve my synthesis" rounds.

## Cost

Each run is three full subagent reviews (one of them on Opus) plus the
session's own verification. In the eval suite below a with-plugin run cost
about five times as much as the session reviewing alone (mean $0.93 per run
that used the skill, against $0.18). When you invoke it by hand, use it where
a wrong verdict costs more than the review; the three automatic moments run
it regardless of cost. The trigger is deliberately wide for documents ("critique
it in detail" fires it), so ask for a quick look instead when that is all you
want.

## Why Fable is on a technical panel

Fable is usually kept for creative writing. Here it adds a third, differently
trained reader. It never reviews alone, and none of its findings counts until
the session has verified it against the source.

## Evaluation

The suite lives in `evals/` and runs with
[`claude plugin eval`](https://code.claude.com/docs/en/plugins):

```
claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp \
  --allow-tools Write Edit --json docs/.results.json
```

Each case is scored with the plugin and without it (the same orchestrator on
Opus, same prompt, same tools), three runs per arm:

| Case | What is planted |
|---|---|
| `code-offbyone` | a `<` that should be `<=` at a date boundary the docstring includes; the tests pass because none covers it |
| `plan-contradiction` | a spec whose 10 MB upload limit contradicts its own 40–60 MB monthly archive |
| `document-report` | a board report claiming growth "every quarter" when the data shows a Q3 dip, and a causal claim from one data point |
| `failure-startup` | an app that fails at startup because `run.sh` does `cd /` and templates are opened by relative path; the orchestrator is also handed a false theory (umask) that must not reach the brief |
| `clean-control` | a correct `clamp` with tests; measures invented findings |
| `witness-contract` | the witness agent alone: report shape, the boundary bug, flagging the requester's opinion, no edits |
| `document-spanish` | a Spanish management report whose "costs fell every quarter" contradicts its data; the report must come back in Spanish |
| `plan-theory` | a migration plan that drops a column before backfilling from it; the session is handed its own theory (a table lock) that must not reach the brief |
| `witness-change` | files in the reviewed repo change while the witnesses run (an eval-only helper plugin's hook stands in for a witness that edits); the after snapshot must catch it |

Results (2026-09-30, orchestrator on Opus, no shell anywhere; mean score over 3 runs per arm):

| Case | With plugin | Without | Delta | With-plugin runs passed |
|---|---|---|---|---|
| clean-control | 0.750 | 0.500 | +0.250 | 2 of 3 |
| code-offbyone | 1.000 | 0.500 | +0.500 | 3 of 3 |
| document-report | 0.944 | 0.833 | +0.111 | 2 of 3 |
| failure-startup | 1.000 | 0.733 | +0.267 | 3 of 3 |
| plan-contradiction | 1.000 | 0.750 | +0.250 | 3 of 3 |
| witness-contract | 1.000 | 0.125 | +0.875 | 3 of 3 |

How to read it:

- document-report comes from a rerun after a fix to the skill's run-directory
  rule (commit `7c7f2b5`). In the full-suite run (commit `1ad1025`) it scored
  0.000: every write of the run directory went outside the working directory,
  was refused, and the skill stopped without reviewing. The other five cases
  were measured at `1ad1025`, before that fix. A last review round then
  changed the skill's wording (see `docs/results.md`); it was not re-measured.
- Only graders that apply to both arms count in the score. The with-only
  indicators (three witnesses dispatched, Fable used, no source pasted into
  the brief, facts in the brief) do not; they passed in every run where the
  skill fired. So a with-plugin run where the skill did not fire can still
  score 0.83 (document-report, run 3).
- witness-contract tests the witness agent itself. Without the plugin the
  agent does not exist, so its +0.875 is not a like-for-like comparison.
- Without the plugin the session usually finds the planted defect too; what it
  loses is mostly the report (no named reviewers, no confirmed / rejected
  split). In some runs the judge also rejects its framing (in code-offbyone it
  offered two fixes instead of calling the `<` the bug; in clean-control it
  listed NaN as should-fix), and in one failure-startup run it passed its own
  theory ("file permissions/umask") to the reviewer.
- The two with-plugin failures: in document-report the skill did not fire in
  one run (the prompt only says "critique it in detail"); in clean-control the
  judge failed a report whose confirmed findings were all minor, and that
  report also did not use the template's section names.

Details, traces and every grader change with its evidence are in
[`docs/results.md`](docs/results.md); the no-plugin baseline is described in
[`docs/baseline.md`](docs/baseline.md).

## Limitations

- **The evals ran without a shell.** Nobody in any eval run, orchestrator or
  witness, had Bash: no `git`, no running tests, no reproducing a failure.
  Every review in the numbers above was done by reading files, and the
  snapshots were a file listing plus line counts. With a shell
  the skill takes real `git status` / hash snapshots and witnesses can run
  things; that path has not been measured.
- **Paths no eval exercises:** retrying a failed witness, missing witnesses
  and the insufficient mark, disputes, and launching unasked. A hook like
  witness-change's could simulate a lost witness report; that case is not
  written yet. The after-snapshot case uses a hook that changes files while
  the witnesses run, not a real witness that edits, and the spec's "after
  snapshot shows no change" has no grader.
- **The raw eval results are not in the repo** (`docs/.results*.json` are
  ignored); `docs/results.md` quotes the numbers and traces they come from.
- **The snapshot detects, it does not prevent.** Witnesses have the same tools
  as the session and are told to change nothing. That is an instruction, not
  a sandbox; the before/after snapshot is what catches a breach.
- **Triggering is not guaranteed.** Asked to "critique" a document without
  the words "independent" or "review", the session used the skill in 2 of 3
  runs. Type `/expert-witness` when you want it for sure.
- **Graders are partly LLM judges** (Haiku by default) and three runs per arm
  is a small sample. `clean-control` has been flaky: the judge sometimes fails
  a report whose confirmed findings are all minor.
- **Verification is only as good as the session's reading.** A finding the
  session cannot check is reported as "could not verify", not dropped and not
  confirmed.
- Everything runs inside Claude Code as subagents; nothing is sent to other
  providers.

## Credits

Inspired by [AltimateAI/claude-consensus](https://github.com/AltimateAI/claude-consensus).
Licensed under the MIT License (see [`LICENSE`](LICENSE)).
