---
name: expert-witness
description: Use when a spec, plan, design or document has just been written and is about to be acted on; when a failure has resisted two fix attempts; when a change is hard to undo or touches security; or when the user asks for an independent, blind or multi-model review or audit of code, a plan, a document or a failure.
---

# Expert witness

Three witnesses who have never seen this session review the subject and
report to you. You write their brief, snapshot, dispatch, verify and report.
You are not a fourth witness: you do not add findings of your own.

Why: you believe the story this session has built. Witnesses who never saw it
cannot share that belief. Everything below protects their independence.

## When you launch it yourself

Only at these moments:
1. a spec, plan or design has just been written, before the next stage;
2. a failure you have already failed to fix twice;
3. a change that is hard to undo or touches security.

Announce it in one line (what and why) and carry on without waiting. Do not
re-run on the same subject unless something new has happened: new commits,
new evidence, or the user disputes a verdict.

## Steps

1. **Run directory.** Your scratchpad directory if the harness gives one,
   else `mktemp -d`. Never inside the reviewed repo or next to the reviewed
   file. With no shell: a new directory beside the reviewed repo or file
   (never inside it), such as `<parent>/expert-witness-run-<n>/`.

2. **Brief.** Copy `brief-template.md` to `<run>/brief.md` and fill every
   slot. The request is the user's own words, quoted exactly. Material is
   pointers, never pasted content.

   For a failure, "Observed facts" holds only things that were seen: the
   symptom, how to reproduce it, errors and logs verbatim, and each thing
   tried with what happened. Your theories go nowhere in the brief.

3. **Before snapshot.** In a git repo: `git status --porcelain` and
   `git rev-parse HEAD`. Otherwise: a hash of every file the brief points at.
   Save it as `<run>/before.txt`. With no shell, say so up front and do not
   dispatch helpers to run commands: the snapshot is the list of files the
   brief points at with their sizes (Glob, Read), or the exact line
   `snapshot unavailable: no shell`. The report then says the change check
   was limited.

4. **Dispatch.** In ONE message, three Agent calls:
   `subagent_type: "expert-witness:witness"` with `model: "sonnet"`, then
   `"opus"`, then `"fable"`. Each prompt is exactly:
   `Your brief is <run>/brief.md. Write your report to <run>/witness-<model>.md.`

5. **After snapshot.** Repeat step 3 into `<run>/after.txt` and compare.

6. **Collect.** Read each `witness-<model>.md`. A witness that failed, or
   whose report lacks the finding fields or the closing sections, is
   dispatched once more with the same prompt. If it fails again, it is
   missing. With one witness left, the report is marked insufficient.

7. **Cluster.** Merge findings about the same location and problem. Record
   who raised each (S, O, F). Keep single-witness findings.

8. **Verify.** For each cluster, open the source and check the evidence: the
   quote exists, the line says that, the log shows that, the data contradicts
   the claim. Mark it confirmed, does not hold (say why), or could not verify
   (say why). A finding does not become true because three witnesses said it,
   nor false because one did.

9. **Report.** Fill `report-template.md` in the user's language, save it as
   `<run>/report.md`, and give it to the user.

## Disputes

If the user disputes a verdict, dispatch one fresh witness (any model) on
that single finding: the finding and its evidence as a new brief, without
saying who raised or rejected it. That is the only follow-up.

## Keeping the brief clean

| Thought | Reality |
|---|---|
| "Mentioning my theory saves them time." | It anchors them on it. Their time is not the scarce resource; their independence is. |
| "I'll mark it as unverified." | A marked theory still anchors. It does not go in. |
| "It's not a theory, it's context." | If it says why, it is a theory. Facts say what was seen. |
| "Summarising the request is clearer." | Paraphrase carries your reading. Quote the user. |
| "I'll paste the code so they don't have to look." | Pointers. They explore further than what you would paste. |
| "Two witnesses are enough, skip Fable." | The roster is three. A missing witness is reported, not planned. |

Red flags in a finished brief — rewrite it if you see any: "probably",
"likely", "I think", "suspect", "the cause", "the issue is", "looks like",
"might be", a file you chose to blame, a fix you have in mind.
