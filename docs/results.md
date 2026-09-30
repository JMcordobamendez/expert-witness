# Results

The eval suite runs without Bash: the sandbox backend needs socat, which is not installed on the development machine (WSL). Cases list no Bash in allowed_tools and the eval command gets no --allow-tools Bash.

## Witness

Eval command: `claude plugin eval . --scaffold --trust-plugin --no-publish --ablation none --case witness-contract --allow-tools Write Edit --keep-temp -j 3`.

- **RED (no agent, no `--allow-tools`):** all 3 runs scored 0.125; only `no-edits` passed. The orchestrator answered, for example: "I couldn't run this because the `expert-witness:witness` agent type isn't available in this session. The only agent types here are `claude`, `Explore`, `general-purpose`, `Plan` and `statusline-setup`", and it did not fall back to another agent.
- **Iteration 1 (agent written exactly as designed, same command):** 3 runs at 0.625. `boundary-found`, `opinion-flagged`, `no-edits` passed; `contract` failed 3/3 because no report file existed. Trace evidence: the witness (sonnet) made a `Write` call and got `Write is disabled for this session, in subagents as well as here.`; the run's `init` tools list has no `Write` or `Edit`. `Write` and `Edit` are gated tools: `allowed_tools` in `case.yaml` is not enough, the operator must pass `--allow-tools`. The agent was not at fault, so `agents/witness.md` was not changed. Fix: `--allow-tools Write Edit` on the eval command (never `Bash`).
- **Iteration 2 (same agent, with `--allow-tools Write Edit`):** 3 runs at 1.0, all four graders pass in all 3 runs (`boundary-found`, `contract`, `opinion-flagged` judge votes 3/3 PASS each; `no-edits` 0 Edit calls). Cost about $0.47 per 3-run batch.
- The witness has no shell, so it reports under "Could not check" that it could not run `git show HEAD` and read the working tree instead. This is expected without Bash.
- **Does `no-edits` see a subagent's Edit?** Yes. Subagent tool calls appear in the parent trace as `assistant` events with `parent_tool_use_id` set to the Agent call (the witness's `Write` was recorded with `model: claude-sonnet-5-5`), and `tool_used` counts them. So `no-edits` proves that neither the orchestrator nor the witness edited anything, provided `Edit` is granted with `--allow-tools`; without that grant Edit does not exist in the run and the grader is vacuous.
