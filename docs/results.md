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
`claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp --allow-tools Write Edit --json docs/.results.json`. No Bash anywhere. Per-case reruns add `--case <name>`. `witnesses-dispatched`, `fable-used` and `tool_used: Skill` are with-only indicators under ablation; the with-plugin arm is what is judged.

### Final scores (with / without / delta)

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
