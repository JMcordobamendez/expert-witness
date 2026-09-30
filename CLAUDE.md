# expert-witness

A Claude Code plugin (pure markdown): a skill that sends three blind witness
subagents (sonnet, opus, fable) to review code, plans, documents or failures.

Before doing anything, read `docs/HANDOFF.md`: current state, standing rules
(evals never get Bash; always `--allow-tools Write Edit`; graders are never
softened), the eval command and the open items.
