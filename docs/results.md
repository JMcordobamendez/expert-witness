# Results

The eval suite runs without Bash: the sandbox backend needs socat, which is not installed on the development machine (WSL). Cases list no Bash in allowed_tools and the eval command gets no --allow-tools Bash.

## Witness

Eval command: `claude plugin eval . --scaffold --trust-plugin --no-publish --ablation none --case witness-contract --allow-tools Write Edit --keep-temp -j 3`.

- **RED (no agent, no `--allow-tools`):** all 3 runs scored 0.125; only `no-edits` passed. The orchestrator answered, for example: "I couldn't run this because the `expert-witness:witness` agent type isn't available in this session. The only agent types here are `claude`, `Explore`, `general-purpose`, `Plan` and `statusline-setup`", and it did not fall back to another agent.
- **Iteration 1 (agent written exactly as designed, same command):** 3 runs at 0.625. `boundary-found`, `opinion-flagged`, `no-edits` passed; `contract` failed 3/3 because no report file existed. Trace evidence: the witness (sonnet) made a `Write` call and got `Write is disabled for this session, in subagents as well as here.`; the run's `init` tools list has no `Write` or `Edit`. `Write` and `Edit` are gated tools: `allowed_tools` in `case.yaml` is not enough, the operator must pass `--allow-tools`. The agent was not at fault, so `agents/witness.md` was not changed. Fix: `--allow-tools Write Edit` on the eval command (never `Bash`).
- **Iteration 2 (same agent, with `--allow-tools Write Edit`):** 3 runs at 1.0, all four graders pass in all 3 runs (`boundary-found`, `contract`, `opinion-flagged` judge votes 3/3 PASS each; `no-edits` 0 Edit calls). Cost about $0.47 per 3-run batch.
- The witness has no shell, so it reports under "Could not check" that it could not run `git show HEAD` and read the working tree instead. This is expected without Bash.
- **Does `no-edits` see a subagent's Edit?** Yes. Subagent tool calls appear in the parent trace as `assistant` events with `parent_tool_use_id` set to the Agent call (the witness's `Write` was recorded with `model: claude-sonnet-5-5`), and `tool_used` counts them. So `no-edits` proves that neither the orchestrator nor the witness edited anything, provided `Edit` is granted with `--allow-tools`; without that grant Edit does not exist in the run and the grader is vacuous.

## Orchestrating skill (Task 5)

Full-suite command (default ablation with-without; the no-plugin arm reruns under the same flags, so the delta is fair):
`claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp --allow-tools Write Edit --json docs/.results.json`. No Bash anywhere. Per-case reruns add `--case <name>`. `witnesses-dispatched`, `fable-used`, `no-pasted-source` and `facts-in-brief` are with-only indicators under ablation; the with-plugin arm is what is judged.

### Scores at handoff (superseded by "Final rerun" below)

| Case | With | Without | Delta | Source of the numbers |
|---|---|---|---|---|
| clean-control | 0.917 | 0.500 | +0.417 | final full suite (1.0, 1.0, 0.75) |
| code-offbyone | 1.000 | 0.583 | +0.417 | final full suite |
| document-report | 1.000 | 0.833 | +0.167 | final full suite |
| failure-startup | 1.000 | 0.800 | +0.200 | final full suite |
| plan-contradiction | 1.000 (5 of 5 clean runs; iteration 1 3/3 vs 0.75 without) | 0.750 | +0.250 | iteration 1 rerun; in the final suite runs 0 and 1 scored 1.0 and run 2 died with "You've hit your session limit" |
| witness-contract | 1.000 | 0.125 | +0.875 | first full run; in the final suite all 6 runs died with the session limit (cost 0.00, `err: exit 1`) |

Environment failure, not the skill: the account's session limit ("resets 7:20pm Europe/Madrid") was hit during the final full-suite run, so `plan-contradiction` run 3 and all of `witness-contract` in that run are void (score 0.125 with an `exit 1` error and cost 0.00). A rerun of `witness-contract` at 14:42 CEST failed the same way, so the "one full rerun after the cap" is incomplete for those two cases. Their numbers above come from the earlier full run and iteration 1, both made with the same agent and no change to it since. The skill did change after those runs only in iteration 2 (run-directory placement wording), which could not have affected `witness-contract` (it does not use the skill).

Cost: full run 1 $15.03, iteration 1 reruns $14.88, iteration 2 reruns $6.40, final full run $16.47. Total about $52.8.

### Run 1 (skill as designed, plus ruling R3 wording)

Scores with / without: clean-control 0.083 / 0.250, code-offbyone 1.0 / 0.75, document-report 0.833 / 0.833, failure-startup 0.867 / 0.800, plan-contradiction 0.75 / 0.75, witness-contract 1.0 / 0.125. Failures:

- `report-shape` failed in every with-plugin run of clean-control, failure-startup, plan-contradiction and document-report. Trace evidence: the final message was a prose summary ending "The full report is at .../report.md", not the template; findings were grouped "Critical / Important / Minor" and rejected ones omitted.
- `no-invented` failed 3/3 in clean-control: the orchestrator "confirmed" NaN behaviour (from Sonnet, Opus and Fable, Fable rating it important) although the docstring and tests promise nothing about NaN.
- `witnesses-dispatched`, `fable-used` failed 3/3 in document-report: the prompt says "Critique it in detail", the Skill tool was never called (0 `Skill` calls) and the orchestrator critiqued alone.
- `no-pasted-source` failed 3/3 in code-offbyone: see grader bug 1 below.

### Iteration 1 (edit + rerun of the five failing cases)

Changes to `skills/expert-witness/SKILL.md`:
1. Description: "review, audit or critique of ... a document (a report, a proposal, a piece of writing)". Baseline failure 3.
2. Step 8: a "confirmed" definition (contradicts what the subject itself promises, or a wrong result on an accepted input; needing an input the subject never promises to handle is minor at most or does not hold; the orchestrator sets severity; if nothing critical or important is confirmed, the report says so in its first line). Form: a positive criterion, not a prohibition. Baseline failure 7.
3. Step 9: the final message is the filled template itself with every section, witnesses named with model, location, quoted evidence and proposal per finding; a prose summary pointing to the file is not the report. Baseline failure 10.

Result: clean-control 1.0 x3 (without 0.25), plan-contradiction 1.0 x3 (0.75), code-offbyone 1.0 x3, failure-startup 0.8, 1.0, 1.0, document-report 0.83, 0.83, 0.0 (skill now fired, 1 Skill call each).

Remaining failures and evidence:
- document-report: the orchestrator picked `/tmp/claude-eval-<id>/expert-witness-run-1/` (the parent of the working directory) as run directory; the `Write` of `brief.md` was refused ("file writes are blocked"), and it critiqued the report itself. Skill gap in the no-shell placement rule.
- failure-startup run 1: `theory-not-in-brief` matched, but the match was in the final `report.md` `Write` (parent_tool_use_id None), where the orchestrator honestly says "My earlier working theory in this session was that the umask ... None of the witnesses was told this theory." The brief and the three `Agent` prompts contain no `umask` (0 matches with a brief-only pattern; the brief did contain `reinstall`). See grader bug 2.

### Iteration 2 (edit + rerun of document-report and failure-startup)

Change to SKILL.md step 1: without a shell, the run directory goes in the parent of the directory that holds the reviewed repo or file, inside the working directory; if a write is refused, try another place outside the reviewed subject; if none accepts a write, say so and stop instead of reviewing it yourself.

Result: document-report 1.0 x3 (without 0.833), failure-startup 1.0 x3 (without 0.8).

### Grader bugs (grader changed, with evidence)

1. `evals/code-offbyone/graders/no-pasted-source.md` matched any `Write` containing `timedelta`. In run 1 the four hits per trace were the three witnesses' report files and the orchestrator's `report.md` (evidence quoting `start = today - timedelta(days=n)` is required by the witness contract), not the brief or a dispatch prompt. The brief-only pattern gives 0 matches on all three traces, and a positive control (`last_n_days` in a `brief.md` Write) matches. The pattern now covers `Agent` inputs and `Write` to `*brief.md`.
2. `evals/failure-startup/graders/theory-not-in-brief.md`: same class of bug. It now covers `Agent`/`Bash` inputs and `Write` to `*brief.md`; the final report may legitimately say the earlier theory was refuted. A leak into a brief or dispatch is still caught.

### Flaky case

clean-control final full run: 1.0, 1.0, 0.75. The failing run's report is correct (no confirmed findings, NaN under "Does not hold", first line says nothing blocks merging); the `report-shape` judge failed it 3/3 because there are no findings with location, evidence and fix among the confirmed ones. Iteration 1 passed 3/3. Recorded as flaky; not tuned further.

### Deviations from the brief's verbatim SKILL.md

- Step 1 and step 3: no-shell wording (rulings R3; run-directory placement refined in iteration 2).
- Description: adds "critique" and examples of documents (iteration 1).
- Step 8: adds the "confirmed" definition and the severity rule (iteration 1).
- Step 9: the final message is the filled template (iteration 1).
- `.gitignore` gains `docs/.results.json` (R2); `docs/baseline.md` gains the R7 note.

## Task 5 review (fresh reviewer, no session context)

### Verdict on the two grader changes

Partly a real bug, partly weaker. The old patterns matched legitimate content: the witnesses' `witness-*.md` Writes quote the source (the contract requires verbatim evidence) and the final `report.md` may say the refuted theory was refuted. Narrowing to the brief and the dispatch prompts was right: the spec checks "the theory is not in `brief.md`" and plan Review Focus 4 checks "the brief never pastes the source". But the narrowed patterns had two holes, tested with synthetic JSON-lines in Python `re` and Node `RegExp` (the grader engine):

1. They required `"file_path"` to be the first key of the Write input, so a brief Write with `content` first, leaking the theory or the source, passed. The old pattern caught it.
2. Neither the old nor the new pattern saw `Edit`. Filling the template without a shell is naturally a Write followed by Edits, so a theory added by Edit went unseen.

Fix (commit `1ad1025`): the Write branch became `"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*brief\.md")[^\n]*<word>`, which matches in any key order and covers Edit. Controls: Write of `brief.md` with `file_path` first, with `content` first, an Edit of `brief.md`, and an Agent prompt all match; a clean brief, `report.md` naming the word, and a witness report that cites `"/x/brief.md"` inside its text do not. The same shape was applied to `facts-in-brief` (positive grader), whose old pattern passed on `reinstall` anywhere in any Write, including a witness report. All three changes make the graders stricter, not softer. The earlier sentence "A leak into a brief or dispatch is still caught" (grader bug 2 above) overstated the old fix.

Not changed: `theory-not-in-brief` still matches `umask` in any Bash input. Bash is never granted (R1), so this has no effect today; whoever grants Bash later should restrict that branch to commands that write `brief.md`.

### Skill fixes from the review

- Step 8: iteration 1 made "confirmed" mean "contradicts what the subject promises", which contradicts the spec (confirmed = the evidence checks out against the source) and would reject in-scope findings such as security, missing tests, plan gaps or a mismatch with the request. Now: confirmed means the source shows what the finding says; the subject's promises decide severity (critical or important only against a promise, the request, or a security or data-loss risk; an unpromised input is minor).
- Step 2: the spec's "reread the brief and remove any sentence that states or implies a conclusion" is now an explicit step, not only the red-flag list.
- Step 4: dispatch in the foreground and wait for all three (baseline run 3 of plan-contradiction ended its turn on a background dispatch).
- Step 1: the no-shell run directory is `./expert-witness-run-<n>/` in the working directory, only when that directory is not the reviewed repo and does not directly hold the reviewed file. The iteration-2 wording ("the parent of the directory that holds the reviewed repo, inside the working directory") was self-contradictory for `./repo`.
- Step 3: the no-shell snapshot is a Glob of the whole reviewed tree plus line counts (Glob and Read give no byte sizes, and a list of pointed-at files cannot show a file a witness creates).
- `brief-template.md`: the report path is left to the dispatch prompt, so all three witnesses get the identical brief the spec requires.
- `report-template.md`: a verdict line under the header (step 8 asked for it "in the first line", which is the header), and "Changes made by witnesses" says when the snapshot was limited.

## Final rerun (after the Task 5 review)

Full suite at commit `1ad1025`, same command as above (`--allow-tools Write Edit`, no Bash), 3 runs per arm, 659 s, $15.00. Then document-report alone at commit `7c7f2b5` (step 1: try the working directory first), $2.20.

| Case | With | Without | Delta | With-plugin runs | Mean cost per run (with / without) |
|---|---|---|---|---|---|
| clean-control | 0.750 | 0.500 | +0.250 | 1.0, 0.25, 1.0 | $1.09 / $0.20 |
| code-offbyone | 1.000 | 0.500 | +0.500 | 1.0, 1.0, 1.0 | $0.88 / $0.20 |
| document-report | 0.944 | 0.833 | +0.111 | 1.0, 1.0, 0.83 | $0.63 / $0.11 |
| failure-startup | 1.000 | 0.733 | +0.267 | 1.0, 1.0, 1.0 | $0.86 / $0.17 |
| plan-contradiction | 1.000 | 0.750 | +0.250 | 1.0, 1.0, 1.0 | $0.91 / $0.21 |
| witness-contract | 1.000 | 0.125 | +0.875 | 1.0, 1.0, 1.0 | $0.13 / $0.07 |

All numbers are from these two runs; none is carried over from earlier runs. document-report comes from its rerun; in the full run it scored 0.000 (see below). Suite verdict: not all green. Four cases pass 3/3; clean-control and document-report pass 2/3.

- **document-report, full run: 0/3.** The skill fired, but in every run the orchestrator wrote `brief.md` to two places outside the working directory (such as `/tmp/claude-eval-<id>/expert-witness-run-1/`, `/tmp/claude-eval-<id>/home/expert-witness-run-1/` or `/tmp/expert-witness-run-1/`), both Writes were denied ("Permission to use Write has been denied because Claude Code is running in don't ask mode"), and it stopped as step 1 says, without reviewing. It never tried the working directory, which holds only `board/`. The review-fix wording of step 1 was still read as "go above the working directory". Step 1 now says to try `<working directory>/expert-witness-run-<n>/` first and when that is wrong. Rerun: runs 1 and 2 used `cwd/expert-witness-run-1/` and scored 1.0; in run 3 the Skill was never called (the orchestrator read the two files and critiqued alone, 0.83 on the both-arm graders, as the no-plugin arm does). Triggering on "Critique it in detail" is therefore 2/3, not reliable.
- **clean-control run 2: 0.25.** `no-invented` judge FAIL x3. The report's own verdict line says "The last commit has no critical or important problems"; it confirms four findings, all marked minor (NaN value, NaN bounds, float/int tests, return type), and puts Fable's "important" rating under Disagreements with the orchestrator's reason for minor. The grader allows minor findings, so this looks like a judge error, probably provoked by the sentence "worth doing before the merge". The grader was not changed. That report also broke step 9: its sections are "Findings" and "Rejected findings" rather than the template's, and it has no "Could not verify". This is also a consequence of the step 8 fix: NaN findings are now confirmed as minor (spec-compliant) instead of "does not hold", which the Haiku judge sometimes reads as invented. Runs 1 and 3 passed.
- **Cost.** On the five skill cases a with-plugin run that used the skill cost about 5.2 times a no-plugin run (mean $0.93 over 14 runs vs $0.18; $0.87 if the run where the skill did not fire is included).
- **Grader regression check.** The tightened `no-pasted-source`, `theory-not-in-brief` and `facts-in-brief` all passed on every with-plugin run. `theory-not-in-brief` failed one no-plugin run of failure-startup (the orchestrator put `umask` in its reviewer's prompt), which is the leak the grader exists to catch.

## Final whole-branch review (fresh reviewer on Opus)

Fixed in one round, after the measurements above (so not re-measured):

- SKILL step 1: the no-shell run directory goes in the working directory only when that is not inside a git repository; the `./app` example allowed an untracked folder in the reviewed repo, against the spec.
- SKILL step 2 and `brief-template.md`: the four kinds are defined (all three plan-contradiction briefs said `Kind: document` for a spec; the spec makes a spec a `plan`), and the spec's `.docx` rule is in.
- SKILL description: auto-launch after "a spec, plan or design" (the description also said "or document", which the body and spec do not).
- SKILL step 8: critical or important also when the problem would stop the subject serving its purpose (a plan step that cannot work, information the reader needs), so plan gaps and missing board information are not capped at minor.
- Spec text restored: "the cost of a run is not a reason to skip it", live-system state in the snapshot, zero witnesses answering, "(or of the proposed fixes)" in the witness's unintended consequences; the duplicate run path dropped from step 9.
- `facts-in-brief` (with-only, so not in the score): the old pattern passed on the log line "(after reinstalling dependencies)" pasted verbatim, even without a `Tried:` line; it now needs `reinstall` on a `Tried:` line of the brief or dispatch (`[Rr]`, since the request says "Reinstalling"). Checked on the real traces: the three with-plugin failure-startup runs still match; the three no-plugin runs no longer do. Stricter, not softer.
- README: the table notes say which runs and commits the numbers come from, which graders count, that witness-contract is not like-for-like, what the no-plugin runs actually did wrong (the earlier "misses the bug" and "invents a blocker" were not supported by the traces), the cost ratio, and the paths no eval exercises.

Left unfixed:

- (Fixed in the next section, commit `f0e53fd`.) `evals/code-offbyone/fixture/window.py` (and the witness-contract copy): the docstring contradicts itself ("within the last n days, today included" is n days; "exactly n days before today is included" is n+1). A no-plugin run pointed this out and the `offbyone` judge failed it. The fixture should say "from n days before today through today, both ends included"; changing it needs a rerun of both cases, which was not done.
- The five cases other than document-report were not rerun after the step-1 fix or this round.

## Session 2: fixture fix, new cases, final runs

All runs below: `--allow-tools Write Edit`, no Bash anywhere, 3 runs per arm,
default ablation (with-without). Total cost of this session's evals: $68.49.

### Fixture docstring (commit `f0e53fd`)

`last_n_days` in `evals/code-offbyone/fixture/window.py` and the
witness-contract copy now says "Return the entries dated from n days before
today through today, both ends included. An entry dated exactly n days before
today is included, so the window spans n + 1 calendar days." `start <
e["date"]` is still the single planted bug; both fixture tests pass with it,
and an entry dated `today - n` is still dropped. Graders unchanged.

- witness-contract: 1.000 / 0.125, 3 of 3 ($0.63).
- code-offbyone, first rerun: **0.000 / 0.833** ($1.18). Not the fixture: see
  the next heading.

### Step 1 regression 1: a parent `.git` (commit `6becd27`)

Trace (all three with-plugin runs): the orchestrator wrote `brief.md` to
`/tmp/claude-eval-<id>/expert-witness-run-1/` and `/tmp/expert-witness-run-1/`,
both denied ("Permission to use Write has been denied because Claude Code is
running in don't ask mode"), and stopped: "The only folders left are inside git
repos (your working directory and the home directory above it)". The eval
harness keeps a `.git` in `home/`, the parent of the working directory
`home/cwd`, and the `7b3b1ea` wording of step 1 ("not inside a git repository
(no `.git` in it or in any parent)") ruled the working directory out. So every
no-shell run since `7b3b1ea` stopped before dispatching; that commit was never
measured. Fix: the rule forbade only the reviewed repository. Rerun:
code-offbyone **1.000 / 0.833**, 3 of 3 ($3.32). The no-plugin arm rose from
0.500 to 0.833: with the unambiguous docstring the judge accepts its boundary
finding.

The same commit forced the template's headings in step 9 (clean-control run 2
at `1ad1025` used "Findings" / "Rejected findings") and widened the
description to a plain "critique it in detail" (document-report fired the
skill in 2 of 3 runs at `7c7f2b5`).

### New cases (commit `fdbc07f`)

- `document-spanish`: a Spanish management report claims logistics costs fell
  every quarter; the CSV shows T3 (381 000 €) above T2 (365 000 €). Graders:
  `false-claim` (llm, 3), `spanish` (llm, 2: headings and prose in Spanish),
  `report-shape`, plus the with-only dispatch and Fable indicators.
- `plan-theory`: a migration plan whose step 3 drops `users.email` before
  step 4 backfills `contacts.email` from it. The prompt hands the orchestrator
  its own theory (the step 5 table lock, "the rest is fine").
  `theory-not-in-brief` (regex, both arms, not_contains) checks the brief's
  Write/Edit and every Agent prompt; `drop-before-backfill` (llm, 3).
- `witness-change`: the case loads an eval-only helper plugin
  (`evals/witness-change/helper`, `plugins: ["../..", "helper"]`) whose
  `SubagentStop` hook appends a line to `repo/clamp.py` and creates
  `repo/NOTES.txt` while the witnesses run. `change-reported` (llm, 3) needs
  the report to name the change. The hook runs as a harness hook with `sh`,
  outside the agent's sandbox; no Bash tool is granted to anyone, so R1 holds.
  Project-level `.claude/` settings and hooks are not loaded in eval runs, so
  a plugin was the only way to change a file mid-run.
- Skipped: a real witness that edits. The witness agent is told to change
  nothing and cannot be replaced in a case, so the hook stands in for it.
  Retry, missing witnesses and disputes are not covered; a hook that deletes a
  witness report could simulate a lost report, and was left for later.

Smoke run of witness-change (1 run per arm, $1.11): with 1.0, without 0.

### Full suite at `fdbc07f` (1164 s, $27.50)

All nine cases pass: clean-control 1.000 / 0.000, code-offbyone 0.917 / 0.833,
document-report 1.000 / 0.833, document-spanish 1.000 / 0.833,
failure-startup 1.000 / 0.800, plan-contradiction 1.000 / 0.750, plan-theory
1.000 / 0.600, witness-change 1.000 / 0.000, witness-contract 1.000 / 0.125.
26 of 27 with-plugin runs perfect. document-report fired the skill 3 of 3.

The one failure: code-offbyone run 1, `report-shape` judge FAIL x3. The report
was complete, but F1's proposal was "Decide which behaviour you want" with two
options, and the "Could not verify" items had no location or evidence;
criterion (b) asks for location, quoted evidence and a proposed fix for each
finding. The grader is right; step 9 was tightened (next heading).

### Final whole-branch review (fresh subagent on Opus) and fixes (commit `196ebd2`)

Confirmed and fixed:
- witness-change could pass for the wrong reason: the hook's text ("edited
  while the review ran") announced itself. It now appends neutral text
  (`DEFAULT_LOW = 0`, a NOTES.txt todo), and a new with-only regex
  `snapshot-caught` needs a Write of `after.txt` that lists `NOTES.txt`.
  Checked on the three with-plugin traces of the `fdbc07f` run: all match.
- plan-theory's regex only caught the literal word "lock"; a paraphrase ("the
  main risk is step 5 on a 2.3-million-row table") passed. It now also
  catches `LOCK`, `step 5`, `2.3`, `million`, `NOT NULL`, "real risk" and "rest
  is fine". Stricter: still absent in the three with-plugin traces, still
  present in the three no-plugin ones.
- Step 1 used the eval layout (`./repo`) as its example and did not define
  "reviewed repository" for a plan or document; step 9 kept the English
  "None" in translated reports and was unclear about "Diagnosis"; the
  description read "a failure that is ... in detail"; README and HANDOFF were
  stale. All reworded.

Declined: making `change-reported` with-only. With-only graders do not count
in the score, so the case would pass or fail on `report-shape` alone and never
on the change it exists to test. It stays scored in both arms; its delta is
recorded as not like-for-like (the no-plugin arm loads no helper).

### Full suite at `196ebd2` (1118 s, $25.53)

Seven cases 3 of 3: clean-control 1.000 / 0.500, code-offbyone 1.000 / 0.750,
failure-startup 1.000 / 0.800, plan-contradiction 1.000 / 0.750, plan-theory
1.000 / 0.600, witness-change 1.000 / 0.083, witness-contract 1.000 / 0.125.

**Step 1 regression 2:** document-report 0.333 and document-spanish 0.444,
1 of 3 each. In the four failing runs the orchestrator wrote `brief.md` to
`/tmp/expert-witness-run-1/` and to the parent of the working directory
(denied), never to the working directory, and stopped. The review-round
wording ("not inside the git repository that contains the reviewed material")
was read against the harness's `home/.git`, which does contain `./board` and
`./informe`. The code cases were unaffected because the reviewed repo is
`./repo`, below the working directory.

Fix (commit `8508aa9`, iteration 1 of 3 for both cases): a rule the
orchestrator can check without a shell. The working directory is wrong only if
it holds a `.git` itself or the request names a repository it is inside; a
`.git` further up that the request never mentions does not count. "Next to the
reviewed file" was dropped; the spec only forbids the reviewed repo. Known
cost: without a shell, working in a subdirectory of the user's repo and asking
about a document without naming the repo, the run directory can land inside
that repo. With a shell the scratchpad or `mktemp -d` is used and this rule
does not apply.

Reruns at `8508aa9`: document-report 1.000 / 0.833 and document-spanish
1.000 / 0.833, 3 of 3 each ($5.86); code-offbyone as a control 1.000 / 0.750,
3 of 3 ($3.36). All nine with-plugin runs wrote the brief in the working
directory at the first try.

### Final table

| Case | With | Without | Delta | With-plugin runs | Commit |
|---|---|---|---|---|---|
| clean-control | 1.000 | 0.500 | +0.500 | 3 of 3 | `196ebd2` |
| code-offbyone | 1.000 | 0.750 | +0.250 | 3 of 3 | `8508aa9` |
| document-report | 1.000 | 0.833 | +0.167 | 3 of 3 | `8508aa9` |
| document-spanish | 1.000 | 0.833 | +0.167 | 3 of 3 | `8508aa9` |
| failure-startup | 1.000 | 0.800 | +0.200 | 3 of 3 | `196ebd2` |
| plan-contradiction | 1.000 | 0.750 | +0.250 | 3 of 3 | `196ebd2` |
| plan-theory | 1.000 | 0.600 | +0.400 | 3 of 3 | `196ebd2` |
| witness-change | 1.000 | 0.083 | +0.917 | 3 of 3 | `196ebd2` |
| witness-contract | 1.000 | 0.125 | +0.875 | 3 of 3 | `196ebd2` |

On the eight skill cases a with-plugin run cost $0.98 on average against
$0.18 without (about 5.5 times; 24 runs each, from the rows above).

Lesson recorded: both regressions came from step 1 wording that was changed
and not measured, or measured only on some cases. Any change to step 1 needs
a rerun of at least one code case and one document case.

## Session 3: Opus judge, anchoring, negative trigger, lost witness

Work on branch `claude/fix-fixture-docstring-qulkpg`, based on `feat/v1` at
`c2e723a`. Every run in this section used `--judge-model opus` (the
harness default is Haiku), with the usual flags and no Bash.

### New cases (commit `efc8e16`)

- `failure-anchored`: an orders service fails at boot with
  `ConnectionRefusedError`. The real cause is that `app/settings.py` looks
  for `app/config/app.env`, the file is `config/app.env`, the loader skips
  a missing file silently and `DB_PORT` falls back to `5433` while
  PostgreSQL listens on `5432`. The session is handed a plausible wrong
  theory: a boot-time race with PostgreSQL (the unit really has no
  `After=postgresql.service`). The request adds a decisive fact: a manual
  start the next morning failed the same way. `cause` (llm, weight 3, both
  arms) fails the run if the diagnosis's main cause or main fix is the race,
  ordering or retries; `theory-not-in-brief` (regex, both arms) as in
  failure-startup.
- `failure-anchored-weak`: the same, without the manual start in the request
  or the log, so only the code and config rule the race out.
- `quick-look`: negative trigger. "Quick one: is the title of
  ./board/report.md OK for a board paper? A line or two is enough." on the
  document-report fixture. `no-review-run` (regex, both arms) fails on any
  Skill call naming expert-witness or any `expert-witness:witness` dispatch;
  `short-answer` (llm) fails a full review.
- `witness-missing`: the clamp repo, plus an eval-only helper plugin whose
  SubagentStop hook deletes every `witness-fable.md` under the working
  directory. `fable-retried` (tool_used, with-only): at least two Agent calls
  naming `witness-fable`; `missing-reported` (llm, weight 3, both arms, like
  witness-change's `change-reported`): Fable named as missing, Sonnet and
  Opus as answering, not marked insufficient.

Smoke run of three of them before the commit ($10.72): all 3 of 3 with the
plugin. The traces showed each grader was not passing vacuously: in
witness-missing every with-plugin run dispatched Fable twice and its report
header read "Witnesses: S, O (F missing)"; in quick-look no run fired the
skill; in failure-anchored the no-plugin session itself dispatched a
general-purpose reviewer without the theory ("a second agent that hadn't
seen my theory") and both arms found the port.

### Full suite at `efc8e16`, Opus judge (1918 s, $46.11)

| Case | With | Without | With-plugin runs passed |
|---|---|---|---|
| clean-control | 1.000 | 0.250 | 3 of 3 |
| code-offbyone | 1.000 | 0.750 | 3 of 3 |
| document-report | 1.000 | 0.833 | 3 of 3 |
| document-spanish | 1.000 | 0.833 | 3 of 3 |
| failure-anchored | 1.000 | 0.733 | 3 of 3 |
| failure-anchored-weak | 1.000 | 0.800 | 3 of 3 |
| failure-startup | 1.000 | 0.733 | 3 of 3 |
| plan-contradiction | 1.000 | 0.750 | 3 of 3 |
| plan-theory | 0.933 | 0.600 | 2 of 3 |
| quick-look | 1.000 | 1.000 | 3 of 3 |
| witness-change | 1.000 | 0.000 | 3 of 3 |
| witness-contract | 0.625 | 0.125 | 0 of 3 |
| witness-missing | 1.000 | 0.000 | 3 of 3 |

- **witness-contract, `contract` FAIL x3.** The Opus judge's verdict carries
  no rationale, so one report was put to a separate Opus grader with the
  same criterion: all seven fields and both sections are present, but F2's
  Evidence ("the tests use dates 9/29, 9/10, 8/1 and today; none is exactly
  today-7 (9/23)") is the witness's summary, not a quote. All three reports
  had the same pattern on their missing-test finding. The grader asks for "a
  verbatim quote"; the Haiku judge had passed these reports in every earlier
  run. The grader is right; the witness agent was fixed (below).
- **plan-theory run 3, `report-shape` FAIL x3.** The report's findings have
  location, evidence and fix; the traces were deleted before they were
  read, so the judge's reason is not known. 2 of 3 meets the bar; not
  investigated further.
- **Theory leaks without the plugin** (`theory-not-in-brief` matched): plan-theory
  3 of 3 again, failure-anchored 1 of 3, failure-startup 1 of 3 (0 of 6 in
  the two Haiku-judged full runs; the grader is a regex, so the judge is not
  the difference). With the plugin: none. The traces were deleted before
  they were read, so the leaked wording is not quoted here.

### Anchoring: does the theory change the diagnosis? (open item 4 of the review)

No, in these cases. The no-plugin arm's `cause` passed 3 of 3 in
failure-anchored and 3 of 3 in failure-anchored-weak, in both the smoke run
and the full run: every no-plugin session found the port and said its race
theory was wrong, including the runs where the theory reached its reviewer.
The code evidence is decisive and one file away. What the plugin changes
here is the independence of the brief and the report, not the diagnosis. A
case where anchoring does change the outcome would need evidence that is
genuinely ambiguous; none is written.

### Witness fix (commit `2210955`)

`agents/witness.md`: Evidence is only text copied from the material, with
the file named; for something missing, copy the lines that show the gap
(for a missing test, the existing test lines).

- Iteration 1 (the field description only; uncommitted): witness-contract
  1 of 3 ($1.17); clean-control as a control 3 of 3 ($3.88). The failing
  reports still summarised the test dates.
- Iteration 2 (a paragraph with an example, committed): witness-contract
  1.000 / 0.125, 3 of 3 ($1.07). Controls: clean-control 1.000 / 0.250 and
  code-offbyone 1.000 / 0.750, 3 of 3 each ($3.85, $3.50).

### Haiku against Opus as judge

Same graders, different runs, so run-to-run variance is mixed in. With the
plugin, the Opus judge failed one thing the Haiku judge never had
(witness-contract, a real defect) and one report-shape run in plan-theory.
Without the plugin, scores were close (clean-control 0.250 against 0.500,
failure-startup 0.733 against 0.800, the rest equal). No with-plugin pass
under Haiku looked like a false pass except witness-contract.

### Final table (Opus judge)

| Case | With | Without | Delta | With-plugin runs | Commit |
|---|---|---|---|---|---|
| clean-control | 1.000 | 0.250 | +0.750 | 3 of 3 | `2210955` |
| code-offbyone | 1.000 | 0.750 | +0.250 | 3 of 3 | `2210955` |
| document-report | 1.000 | 0.833 | +0.167 | 3 of 3 | `efc8e16` |
| document-spanish | 1.000 | 0.833 | +0.167 | 3 of 3 | `efc8e16` |
| failure-anchored | 1.000 | 0.733 | +0.267 | 3 of 3 | `efc8e16` |
| failure-anchored-weak | 1.000 | 0.800 | +0.200 | 3 of 3 | `efc8e16` |
| failure-startup | 1.000 | 0.733 | +0.267 | 3 of 3 | `efc8e16` |
| plan-contradiction | 1.000 | 0.750 | +0.250 | 3 of 3 | `efc8e16` |
| plan-theory | 0.933 | 0.600 | +0.333 | 2 of 3 | `efc8e16` |
| quick-look | 1.000 | 1.000 | 0.000 | 3 of 3 | `efc8e16` |
| witness-change | 1.000 | 0.000 | +1.000 | 3 of 3 | `efc8e16` |
| witness-contract | 1.000 | 0.125 | +0.875 | 3 of 3 | `2210955` |
| witness-missing | 1.000 | 0.000 | +1.000 | 3 of 3 | `efc8e16` |

`2210955` changes only the witness agent's evidence rule; the rows at
`efc8e16` ran with the earlier wording, whose only measured failure was the
one it fixes. Session 3 eval spend: $70.30.
