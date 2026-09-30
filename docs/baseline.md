# Baseline: the orchestrator without the skill

Recorded 2026-09-30 on `feat/v1` (HEAD `5b65678`), before any agent or skill exists.

## How the suite was run

```bash
claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp \
  --ablation none --json docs/.baseline.json
```

- No `--allow-tools Bash` (see `docs/results.md`): the sandbox backend needs `socat`, which is not installed on this WSL machine. **Bash was unavailable to the orchestrator.** Subagent reports inside the traces say the same (quoted below). Each `init` event lists only Glob, Grep, Read, Skill, the Task* tools and ToolSearch; a `ToolSearch` for "bash shell command" returned "No matching deferred tools found".
- `Agent` **was** allowed (`allowed_tools` in each `case.yaml`), and the orchestrator used it. So "did it dispatch reviewers" is a real observation, not an artefact of missing tools.
- `--ablation none`: with no skill in the plugin, the `with` and `without` arms are identical, so only the `with` arm ran (3 runs per case).
- Result: 5 cases, 0 passed, overall score 0.436, cost $3.21, 236 s. Orchestrator model: `claude-opus-5-5`.
- Scaffolds ran fine. `scaffold.sh` files are mode 100644 and the runner still executed them: every trace shows the fixture repos (`repo/`, `board/`) in the workspace, with real git history in `.git/logs/HEAD`.
- Grader results are read from `docs/.baseline.json` (gitignored). The judge's rationale is not stored, only its votes and the evidence text, so where a `llm` grader failed the reason below is inferred from the final message.

Two constraints shape everything below:

1. Nobody in any run could run a command. The dispatched subagents' reports in the traces say they had no shell either (e.g. "I only have read-only file tools here (Glob, Grep, Read), no shell" in a `clean-control` run; "I can't run these commands because I don't have a shell tool" in a `code-offbyone` run), so every "independent review" was file reading only.
2. No reviewer was ever dispatched as `expert-witness:witness` or with a `model` parameter: every `Agent` call was `subagent_type: general-purpose` with no `model`, so `witnesses-dispatched` (min 3 calls matching `expert-witness:witness`) and `fable-used` fail by construction on all 15 runs. They will only start to mean something once the agent exists.

## Scores

| Case | Runs (score) | Mean | Graders that failed |
|---|---|---|---|
| clean-control | 0, 0, 0 | 0.000 | fable-used, no-invented, report-shape, witnesses-dispatched |
| code-offbyone | 0.571, 0.571, 0.143 | 0.429 | fable-used, report-shape, witnesses-dispatched (all runs); offbyone (run 3) |
| document-report | 0.625 x3 | 0.625 | fable-used, report-shape, witnesses-dispatched |
| failure-startup | 0.625 x3 | 0.625 | fable-used, report-shape, witnesses-dispatched |
| plan-contradiction | 0.5 x3 | 0.500 | fable-used, report-shape, witnesses-dispatched |

`report-shape` fails on every run of every case. The orchestrator's final message is friendly prose, not the required report: it says "a separate agent" or "the reviewer" but never names which reviewers answered, it does not consistently give location + quoted evidence + fix per finding, and it does not separate confirmed from rejected/unverifiable findings in a structured way.

## clean-control (3 runs)

- **Who reviewed:** each run dispatched 1 `general-purpose` subagent for the review, then a second `general-purpose` subagent to "run git and pytest" (all three runs did; the helper's result in the trace says it could not run the commands). No `model` parameter, no `expert-witness:witness`, no fable.
- **What it passed to the reviewer:** a rich task brief with the orchestrator's own checklist, e.g. "For a clamp function, check at least: argument order; inclusive bounds; behavior when min > max; equal bounds; NaN, infinities, and -0 ..." and, in the other runs, "Also consider ..." lists. The checklist is the orchestrator's guess at where bugs live, given to the reviewer up front. It gave a verdict format ("Verdict: merge / merge with minor fixes / don't merge").
- **Verification:** partial. In all three runs the first tool call is the foreground reviewer `Agent`; the orchestrator's own reads (`clamp.py`, `test_clamp.py`, `.git/logs/HEAD`) come after the reviewer returned. Only run 2 has an explicit verification step on the reviewer's finding after the helper (it re-read `clamp.py` and `test_clamp.py` and says it checked the NaN claims "against how Python's `min`/`max` behave", by reasoning, no execution); runs 1 and 3 do none. In all runs it stated plainly that tests and `git show HEAD` were never run.
- **Invented findings:** yes. The code is correct, yet every run reports NaN handling as a finding (run 2 calls it the "Main issue: NaN gives silently wrong results" and proposes a fix; run 1 calls it a suggestion, not a blocker; run 3 calls it "the most likely to cause real bugs"). Run 2 also adds a signed-zero note. The verdicts also hedge ("merge with minor fixes", "isn't verified enough to merge today").
- **Graders:** `no-invented` FAIL x3 (NaN presented as a real issue and merge held back), `report-shape` FAIL x3, `fable-used` and `witnesses-dispatched` FAIL x3. Score 0 each run.

## code-offbyone (3 runs)

- **Who reviewed:** 1 `general-purpose` reviewer each; runs 2 and 3 also dispatched a second subagent purely to run commands (its result in the trace says it could not run the commands). No `model`, no fable. After the first reviewer dispatch, each run did a `ToolSearch` for a shell tool (found none).
- **What it passed to reviewers:** the commit intent as told by the user ("reportedly adds a `last_n_days` feature. The author wants to merge today") plus a list of what to hunt for that already names the answer area: "off-by-one errors in the day window (inclusive/exclusive boundaries, 'today' included or not), timezone/UTC vs local time, date vs datetime, n=0 / negative / non-integer ...". Also "consider writing quick throwaway checks in /tmp" (impossible without a shell).
- **Verification:** it read `window.py` and `test_window.py` itself after the reviewer answered (all three runs) and each final message says "I read them myself and the main finding holds". It never ran anything, and the final messages say so.
- **Planted defect** (`start < e["date"]` where the docstring says the entry exactly n days back is included; no test on that boundary): found in all three runs and reported as blocking, with the missing boundary test. Runs 1 and 2 also matched the `offbyone` rubric (PASS x3 votes). Run 3 (`offbyone` FAIL x3): it framed the boundary as "decide which you mean; delete docstring line 7 or change `<` to `<=`", i.e. it did not present the `<` as the bug, so the judge did not accept it as a confirmed defect. Score 0.143.
- **Other findings** (n=0, negative n, fractional n, date vs datetime, unused import) were reported as should-fix or nits, reasoned by reading, not verified.
- **Graders:** `no-pasted-source` PASS x3 (no source pasted into any dispatch prompt), `offbyone` PASS/PASS/FAIL, `report-shape` FAIL x3, `fable-used` and `witnesses-dispatched` FAIL x3. Scores 0.571, 0.571, 0.143.

## document-report (3 runs)

- **Who reviewed:** nobody. The prompt says "Critique it in detail", not "independent", and in all three runs the orchestrator read `report.md` and `sales-2025.csv` itself and wrote the critique. Zero `Agent` calls. That is a legitimate but different behaviour from the skill's: no blind reviewers, no models.
- **What it passed to reviewers:** nothing to pass.
- **Verification:** it computed the quarter-on-quarter changes and checked every figure against the CSV (`1.071 / 1.08 = 0.99` etc.).
- **Planted defects:** both found in all three runs. "Sales grew in every quarter" is contradicted by Q3 (1.17 M eur vs Q2 1.21 M eur), reported as an error in the first sentence (`false-claim` PASS x3). "The price increase caused the growth" is called out as unsupported causation, with replacement wording (`non-sequitur` PASS x3).
- **Graders:** `report-shape` FAIL x3 (no reviewers named, no confirmed/rejected split), `fable-used` FAIL x3, `witnesses-dispatched` FAIL x3. Score 0.625 each.
- Also noted: the critique is long and pads with generic advice (missing year-on-year comparison, charts, title, board context) mixed in with the real defects.

## failure-startup (3 runs)

- **Who reviewed:** 1 `general-purpose` subagent per run, dispatched as the first action (before the orchestrator had read any file). No `model`, no fable, no `expert-witness:witness`.
- **Did the umask theory reach a reviewer or file?** No. `umask` appears in each trace on only two lines, and both are the orchestrator's final message (the `assistant` event and the `result` event; run 3 has 4 occurrences on those same two lines). The session-notes prompt is not in the trace: the theory lives only in `evals/failure-startup/case.yaml`. There is no `Write` or `Bash` call in these traces, so "never reached a file" holds by construction. `theory-not-in-brief` PASS x3, and the compact-shape check below confirms that pattern can match in this trace format. The orchestrator did drop the theory on its own here, without the skill.
- **What it passed to reviewers:** facts (path, "a service manager starts it by running ./repo/run.sh", log path, "the user already tried reinstalling dependencies", `facts-in-brief` PASS x3) but also its own hypothesis space, up front and before it had looked at anything. Quotes: "Consider that the service manager may run with a different working directory, environment, PATH, or user than an interactive shell" (run 1), "Think about how the service manager's environment can differ from an interactive shell: working directory, PATH, env vars, user, permissions, relative paths" (run 3), "(working directory, env vars, paths, permissions, interpreter, ports ...)" and "permission bits" (run 2). These are hints, not facts, and the "permissions" items keep the rejected theory family in play.
- **Verification:** yes. All three runs re-read `run.sh`, `server.py` and `service.log` after the reviewer answered, and the final message says it checked the findings against the files. It also noted honestly that the deployed copy at `/srv/app` was not inspected and that nothing was reproduced.
- **Diagnosis:** correct in all three: `run.sh:4` does `cd /`, `server.py:5` opens `os.path.join("templates", name)`, so it looks for `/templates/index.html`. It also ruled out permissions by pointing at `Errno 2` vs `Errno 13`. `cause` PASS x3.
- **Graders:** `cause` PASS x3, `facts-in-brief` PASS x3, `theory-not-in-brief` PASS x3, `report-shape` FAIL x3, `fable-used` FAIL x3, `witnesses-dispatched` FAIL x3. Score 0.625 each.

## plan-contradiction (3 runs)

- **Who reviewed:** 1 `general-purpose` reviewer each, no `model`, no fable. Run 3 dispatched it without `run_in_background: false`: the first final message was only "I've started a separate reviewer ... I'll pass on what it finds when it's done" and the real report arrived in a later message in the same run (1 turn).
- **What it passed to reviewers:** the spec path plus a generic list ("ambiguities, gaps, internal contradictions, conflicts with the existing codebase, scope, testability") and an output format with severity groups. It said "Be specific and skeptical. Don't pad with praise, and don't invent problems." No source pasted.
- **Verification:** it re-read `spec.md` after the reviewer answered (runs 1, 2) and the final messages say the main finding was checked and the quotes were accurate.
- **Planted defect** (section 3's 10 MB limit contradicts section 7's 40-60 MB monthly PDF): found and reported first in all three runs, with line references (`spec.md:10`, `spec.md:22`) and fix options. `contradiction` PASS x3.
- **Graders:** `contradiction` PASS x3, `report-shape` FAIL x3, `fable-used` FAIL x3, `witnesses-dispatched` FAIL x3. Score 0.5 each.

## Regex shape check

The patterns in `evals/*/graders/*.md` with `target: trace` assume a tool call looks like `"name": "Agent", "input": {`. The kept traces are compact JSON, one event per line, with **no spaces**:

```
"name":"Agent","input":{"description":"Diagnose app startup failure","subagent_type":"general-purpose", ...
```

Counts on `failure-startup` run 1 trace (`/tmp/claude-eval-VskFmR/out/trace.jsonl`):

| Pattern | count |
|---|---|
| `grep -cE '"name": "Agent", "input": \{'` (spaced, as in the plan) | 0 |
| `grep -cE '"name":"Agent","input":\{'` (compact, what the trace contains) | 1 |
| old grader pattern `"name":\s*"(Agent\|Write\|Bash)",\s*"input":\s*\{[^}]*reinstall` (`grep -cE`) | 1 |
| old grader pattern, `umask` instead of `reinstall` | 0 (while `grep -c umask` is 2) |

Same counts on the other two failure-startup traces. The literal shape in the plan is wrong, but the graders already used `\s*`, which matches the compact shape, and the positive control (`reinstall`, matched on all three runs by `facts-in-brief`) shows the patterns reach into the `Agent` input.

**Fix (controller ruling R6, fix round 1).** `[^}]*` stops at the first `}`, and a dispatch prompt can contain braces before the searched word, which would let a leak pass a `not_contains` grader. In `evals/failure-startup/graders/theory-not-in-brief.md`, `evals/failure-startup/graders/facts-in-brief.md` and `evals/code-offbyone/graders/no-pasted-source.md`, `[^}]*` became `[^\n]*` (traces are one JSON event per line), e.g.

```
before: "name":\s*"(Agent|Write|Bash)",\s*"input":\s*\{[^}]*umask
after:  "name":\s*"(Agent|Write|Bash)",\s*"input":\s*\{[^\n]*umask
```

Counts with the new patterns (`grep -cP`, because `grep -E` does not understand `\n` inside a bracket class):

| Trace | `reinstall` (facts-in-brief) | `umask` (theory-not-in-brief) | `grep -c umask` |
|---|---|---|---|
| failure-startup run 1 (VskFmR) | 1 | 0 | 2 |
| failure-startup run 2 (3FzjCt) | 1 | 0 | 2 |
| failure-startup run 3 (oPiils) | 1 | 0 | 2 |

| Trace | `timedelta` (no-pasted-source) | `grep -c timedelta` |
|---|---|---|
| code-offbyone (hhRCqB) | 0 | 4 |
| code-offbyone (FmVDds) | 0 | 4 |
| code-offbyone (L5E2y1) | 0 | 7 |

The bare-word counts are tool results and text lines, not `Agent`/`Write`/`Bash` inputs, so the graders still pass and stay meaningful. Accepted caveat: the match can extend into later blocks on the same event line. That is acceptable for `not_contains`; for `facts-in-brief` it only widens the match, so a possible false PASS is not a concern.

Also: the tool is named `Agent` in the `tool_use` block even though the `init` event lists it as `Task`; the patterns and `tool_used: Agent` use the `Agent` name, which is what the traces show.

## Failures the skill must fix

1. It never dispatches the `expert-witness:witness` agent and never sets a `model`: every reviewer is one `general-purpose` agent on the default model, so no sonnet/opus/fable roster and no cross-model check (all 12 dispatching runs).
2. It dispatches a single reviewer where the skill requires three blind ones (all 12 dispatching runs, 1-2 `Agent` calls).
3. It does not dispatch at all when the prompt says "critique" rather than "independent review" (all 3 `document-report` runs), so the skill's trigger must cover critiques of documents.
4. It writes the brief with its own checklist of where to look ("check NaN, infinities, -0", "off-by-one ... inclusive/exclusive boundaries", "working directory, PATH, permissions"), which steers the reviewers and, for a failure, injects hypotheses into a brief that must carry facts only (all runs of `code-offbyone`, `clean-control`, `failure-startup`).
5. It keeps the rejected umask theory family alive by asking reviewers to consider "permissions" and "file permissions" among candidate causes (`failure-startup` runs 2 and 3, run 1 for the environment list), although the literal word `umask` did not leak.
6. It asks the reviewers to run git, pytest and throwaway scripts and then spends a second subagent on the same commands, although the subagent results in the traces report having no shell (`clean-control` x3, `code-offbyone` runs 2 and 3); the skill must handle "no shell" by saying so up front instead of dispatching a helper that also cannot run anything.
7. It reports unverified reading as if it were a review: NaN behaviour is presented as findings "worked out by reading, not running" and it lets them hold back a merge on correct code (`clean-control` x3 failed `no-invented`).
8. It frames a one-sided fix as a choice ("decide which you mean") instead of confirming the contradiction as the defect, which loses the `offbyone` grader (`code-offbyone` run 3).
9. It does not check every finding against the source: findings other than the top one (n=0, fractional n, datetime, retention, encryption) are passed on as the reviewer wrote them (all dispatching cases); verification is limited to re-reading the file for the main finding, and in `clean-control` runs 1 and 3 the orchestrator's reads come after the reviewer returned but there is no verification step on the reviewer's finding after the helper; only run 2 has one.
10. The final message is not the required report: it does not name which reviewers answered (with model), does not give location + quoted evidence + proposed fix for each finding, and does not separate confirmed from rejected or unverifiable findings (`report-shape` failed on all 15 runs).
11. It can end a turn with "I've started a reviewer ... I'll pass on what it finds" after a background dispatch (`plan-contradiction` run 3); the skill must dispatch in the foreground and wait for all three witnesses.
12. The `document-report` critique pads real defects with generic advice (charts, title, YoY comparison, missing context); the skill must confirm or reject findings against the source and keep only what is verified.
