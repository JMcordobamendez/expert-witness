# expert-witness — design

**Date:** 2026-09-30
**Status:** draft for review

## Purpose

When an orchestrating Claude Code session has been working on something for a
while, it believes its own story. Its reviews of its own work inherit that
belief: confirmation bias. `expert-witness` gets a second and third opinion
from reviewers who have **never seen the session**. They receive only the
original request, pointers to the material, and (for a failure) the observed
facts. They form their own conclusions and report a diagnosis back to the
orchestrator, which verifies each finding against the real source before
passing it on.

Like an expert witness in court, a witness gives an independent opinion and
does not decide. The orchestrator decides, and the user overrules.

## What it reviews

One run reviews one **subject** of one of four kinds:

| Kind | Examples | What witnesses look for |
|---|---|---|
| `code` | a diff, a branch, a module | bugs, edge cases, security, ripple effects on callers and consumers, missing tests |
| `plan` | a spec, a design doc, an implementation plan, a task | contradictions, gaps, infeasible steps, unstated assumptions, risks, mismatch with the request |
| `document` | a report, a proposal, an article, notes for someone else | claims contradicted by the provided sources, conclusions that do not follow from the data, missing information the reader needs, internal contradictions, clarity and structure for its audience |
| `failure` | a service that will not start, a test that fails, wrong output | the cause, with evidence, and how to confirm it |

Readable inputs: any text or source file, Markdown, PDF. A `.docx` is
converted to text by the orchestrator first (the conversion goes in the run
directory, never next to the original).

## Non-goals

- Witnesses **diagnose and propose**; they never apply fixes. The run produces
  a report, not a rewritten document or a patch. Applying proposals is a
  separate, later request from the user.
- No external model providers, no API keys, no scripts, no dependencies.
  Everything runs inside Claude Code as subagents, so nothing leaves
  Anthropic.
- No "do you approve my synthesis?" convergence rounds (the orchestrator's
  summary is exactly the bias this tool exists to avoid).
- No configuration file. The witness roster is a short list in the skill;
  changing it is a one-line edit.

## Witnesses

Three witnesses per run, the same agent definition dispatched with three
models: **`sonnet`**, **`opus`**, **`fable`**. All three review every kind of
subject, code included.

Using Fable for technical review is a deliberate exception to the author's
general rule of keeping Fable for creative writing. It is acceptable here
because Fable never reviews alone and every finding is verified before it
counts.

Witnesses are ordinary (non-fork) subagents, so they start with no session
context. They have the same tools as the orchestrator (full access) and are
instructed to change nothing: no edits, no writes outside the run directory,
no restarts, no installs, no commits, no network side effects. That is an
instruction, not a sandbox; the before/after snapshot (below) is what catches
a breach. Witnesses must not dispatch subagents of their own.

## Components

```
expert-witness/
├── .claude-plugin/
│   ├── plugin.json            # name, version, description, license, repo
│   └── marketplace.json       # this repo is its own marketplace, source "./"
├── agents/
│   └── witness.md             # the witness: role, method, output contract
├── skills/
│   └── expert-witness/
│       ├── SKILL.md           # the orchestrator: when, brief, dispatch, verify, report
│       ├── brief-template.md
│       └── report-template.md
├── tests/
│   └── cases/                 # seeded-defect cases (see Testing)
├── README.md
└── LICENSE                    # MIT
```

Install:

```
/plugin marketplace add JMcordobamendez/expert-witness
/plugin install expert-witness@expert-witness
```

All files are in English, whatever language the user speaks to Claude in.
The final report is written in the user's language.

### `agents/witness.md`

States the witness's situation plainly: you are an outside expert, you know
nothing about the conversation that produced this subject, reach your own
conclusions from the material, and do not trust any claim in the brief that
is not a pointer or an observed fact. If the brief contains an opinion about
the cause or the quality of the subject, say so in the report and do not
adopt it.

Method: read the whole subject (not only the diff or the named file: follow
callers, sources and references far enough to judge), check claims against
evidence, and look for what is missing as well as what is wrong.

Output contract, one block per finding:

```
### F<n>: <one-line title>
- Severity: critical | important | minor
- Location: <file:line | section + quoted sentence | log + timestamp>
- Evidence: <verbatim quote from the source that shows the problem>
- Problem: <what is wrong and why it matters>
- Proposal: <concrete fix; for a document, the replacement wording>
- Confidence: high | medium | low
- Would be refuted by: <what observation would prove this finding wrong>
```

Followed by two mandatory sections:

- **Unintended consequences:** ripple effects of the subject (or of the
  proposed fixes) on things outside it, or the exact line
  `None found — checked <what was checked>.`
- **Could not check:** what the witness wanted to verify and could not, and
  why.

For a `failure`, the report also opens with **Diagnosis:** the most likely
cause, the evidence for it, and the single cheapest observation that would
confirm or rule it out.

If there are no findings, the witness writes `No findings.` and still fills
the two mandatory sections. A witness that always finds something is useless,
so padding is explicitly discouraged.

### `skills/expert-witness/SKILL.md`

Invoked by the user (`/expert-witness <what to review>`) or on the
orchestrator's own initiative.

**When the orchestrator launches it unasked**, only at these moments:

1. a spec, plan or design has just been written, before moving to the next
   stage;
2. a failure the orchestrator has already failed to fix twice;
3. a change that is hard to undo or touches security.

It announces the launch in one line (what is being reviewed and why) and does
not wait for an answer. It never re-runs on the same subject unless something
new has happened since the last run (new commits, new evidence, the user
disagrees with a verdict). The cost of a run is not a reason to skip it.

**Steps:**

1. **Run directory.** The harness scratchpad if there is one, else
   `mktemp -d`; never inside the reviewed repo (it would pollute
   `git status`).
2. **Brief.** Fill `brief-template.md` and save it as `brief.md` in the run
   directory. All three witnesses get this exact text; nothing else is added
   per witness. Contents:
   - the kind (`code`, `plan`, `document`, `failure`);
   - the user's original request **verbatim** (quoted, not paraphrased);
   - pointers to the material: paths, commit range, URLs, commands to see it;
   - for a `document`, the sources it can be checked against, if any;
   - for a `failure`, **facts only**: the symptom, how to reproduce it,
     errors and logs verbatim, and what has been tried **with what happened**
     ("restarted the service: same error at 07:02"). No hypotheses, no "I
     think", no "probably", no suspected cause, not even marked as
     unverified.
   Before dispatching, the orchestrator rereads the brief and removes any
   sentence that states or implies its own conclusion.
3. **Before snapshot.** Record what a witness could change: in a git repo,
   `git status --porcelain` and `HEAD`; for a live system, whatever the brief
   points at (service state, file hashes).
4. **Dispatch.** The three witnesses in one message, in parallel, each with
   its `model`, each told the path of `brief.md` and where to write its
   report (`witness-<model>.md` in the run directory).
5. **After snapshot.** Compare with the before snapshot. Any difference is
   reported first, above all findings, naming what changed.
6. **Collect.** A witness that errors, times out or ignores the output
   contract is retried once. After that the run continues with the rest and
   the report says which witness is missing. With only one witness left, the
   report is marked **insufficient** (no cross-check was possible).
7. **Cluster.** Findings about the same location and the same problem are
   merged; each cluster records which witnesses raised it (S / O / F). No
   finding is dropped for having a single witness.
8. **Verify.** For each cluster, the orchestrator checks the evidence against
   the real source: the quote exists, the line says that, the log shows that,
   the data contradicts the claim. Each cluster ends up:
   - **confirmed**;
   - **does not hold**, with the reason;
   - **could not verify**, with the reason.
9. **Report.** Fill `report-template.md`, save it as `report.md` in the run
   directory, and give it to the user.

**Disputes.** If the user disagrees with a "does not hold" or with how two
witnesses' disagreement was settled, the orchestrator can dispatch one fresh
witness on that single point: the finding and its evidence only, with no
indication of who said what. That is the only follow-up round.

### `report-template.md`

In this order:

1. **Header:** subject, kind, witnesses that answered, run directory.
2. **Changes made by witnesses:** only if the after snapshot differs.
3. **Diagnosis** (for `failure` only): the confirmed cause, or the competing
   ones.
4. **Confirmed findings,** most severe first. Each with who saw it (S/O/F),
   location, evidence, problem and proposal.
5. **Disagreements:** where witnesses contradicted each other, both sides, and
   the orchestrator's reading.
6. **Does not hold:** discarded findings and why, so the user can overrule.
7. **Could not verify.**
8. **Missing witnesses** and the **insufficient** mark, if any.

## Testing

A skill is only trusted once it has been seen to catch something (a quality
gate that never fails proves nothing). `tests/cases/` holds one directory per
case, each with the material, a `request.md` with the verbatim request, and an
`expected.md` listing the planted defects. Witnesses never see `expected.md`,
which lives outside what the brief points at.

1. **code:** a subtle real bug (an off-by-one bound) in code whose tests pass.
2. **plan:** a spec with two sections that contradict each other.
3. **document:** a report with one claim its attached data contradicts and one
   conclusion that does not follow from the data.
4. **failure:** a small program inside the case directory that fails at
   startup for a specific cause (no real service is touched). The
   orchestrator is handed a false theory along with the facts; the test
   checks that the theory is not in `brief.md`.
5. **clean control:** material with no planted defect, to measure invented
   findings.

**Pass:** every planted defect appears as a confirmed finding; the clean
control has no confirmed finding of severity important or above; no
`brief.md` contains a hypothesis; the after snapshot shows no change.

The skill is written with `superpowers:writing-skills`, so a baseline run
without the skill (the orchestrator reviewing alone) is recorded first and
the same cases are run with it, to show the difference rather than assume it.

## Open points for the plan

- Confirm the exact slash-command name a plugin skill gets
  (`/expert-witness` or `/expert-witness:expert-witness`) and the
  `subagent_type` a plugin agent gets (`expert-witness:witness`), by
  installing the plugin locally before publishing.
- Confirm that `fable` is accepted as a subagent `model` on the user's plan.
