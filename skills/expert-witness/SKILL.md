---
name: expert-witness
description: Use when the user asks for an independent, blind, multi-model or detailed review, audit or critique of code, a plan, a document (a report, a proposal, a board paper, a piece of writing) or a failure, including a plain "critique it in detail" or "review this before it goes out" about something someone wrote; when a spec, plan or design has just been written and is about to be acted on; when a failure has resisted two fix attempts; or when a change is hard to undo or touches security.
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
new evidence, or the user disputes a verdict. The cost of a run is not a
reason to skip it.

## Steps

1. **Run directory.** Your scratchpad directory if the harness gives one,
   else `mktemp -d`. Never inside the reviewed repo (it would show in
   `git status`). With no shell, writes are usually allowed only inside the working
   directory, so try `<working directory>/expert-witness-run-<n>/` first.
   Decide only from what you can see: it is the wrong place only if the
   working directory itself holds a `.git`, or the request names a
   repository that the working directory is inside ("this repo"). A `.git`
   further up that the request never mentions does not count, and a
   reviewed repository below the working directory (such as `./app`) is
   fine. If a write is refused, try another place outside the subject.
   Only when no place accepts a write, say so and stop. Do not review it
   yourself instead.

2. **Brief.** Copy `brief-template.md` to `<run>/brief.md` and fill every
   slot. The request is the user's own words, quoted exactly. Material is
   pointers, never pasted content. The kind is `code` (a diff, branch or
   module), `plan` (a spec, design, plan or task), `document` (a report,
   proposal, article or notes) or `failure` (something that will not start,
   a failing test, wrong output). A `.docx` is first converted to text into
   `<run>/`, never next to the original; point the brief at both.

   For a failure, "Observed facts" holds only things that were seen: the
   symptom, how to reproduce it, errors and logs verbatim, and each thing
   tried with what happened. Your theories go nowhere in the brief.

   Before dispatching, reread `brief.md` and delete every sentence that
   states or implies a conclusion of yours (see the red flags at the end).

3. **Before snapshot.** In a git repo: `git status --porcelain` and
   `git rev-parse HEAD`. Otherwise: a hash of every file the brief points at;
   for a live system, also its state (service status and the like).
   Save it as `<run>/before.txt`. With no shell, say so up front and do not
   dispatch helpers to run commands: the snapshot is a Glob of the whole
   reviewed tree (so new files show) plus the line count of each file the
   brief points at (Read), or the exact line `snapshot unavailable: no
   shell`. The report then says the change check was limited.

4. **Dispatch.** In ONE message, three Agent calls in the foreground (no
   `run_in_background`), and wait for all three before step 5:
   `subagent_type: "expert-witness:witness"` with `model: "sonnet"`, then
   `"opus"`, then `"fable"`. Each prompt is exactly:
   `Your brief is <run>/brief.md. Write your report to <run>/witness-<model>.md.`

5. **After snapshot.** Repeat step 3 into `<run>/after.txt` and compare.

6. **Collect.** Read each `witness-<model>.md`. A witness that failed, or
   whose report lacks the finding fields or the closing sections, is
   dispatched once more with the same prompt. If it fails again, it is
   missing. With one witness left, the report is marked insufficient; with
   none, stop and report that no witness answered.

7. **Cluster.** Merge findings about the same location and problem. Record
   who raised each (S, O, F). Keep single-witness findings.

8. **Verify.** For each cluster, open the source and check the evidence: the
   quote exists, the line says that, the log shows that, the data contradicts
   the claim. Mark it confirmed, does not hold (say why), or could not verify
   (say why). A finding does not become true because three witnesses said it,
   nor false because one did.

   Confirmed means the quote exists and the source shows what the finding
   says. Does not hold means the source does not show it. You set each
   confirmed finding's severity; a witness's rating is an opinion. Critical
   or important only if it contradicts what the subject itself says or
   promises (its docstring, spec, tests, data or log) or the user's request,
   or is a security or data-loss risk, or would stop the subject serving its
   purpose (a plan step that cannot work, information the reader needs to
   decide). A problem that needs an input or use
   the subject never promises to handle is minor. When nothing confirmed is
   critical or important, the report says so on the line right under its
   header.

9. **Report.** Fill `report-template.md` in the user's language and save it
   as `<run>/report.md`. Your final message is that filled template itself.
   Keep the template's headings, in its order, translated word for word
   into the user's language and never renamed or merged: "Changes made by
   witnesses", "Diagnosis", "Confirmed findings", "Disagreements", "Does
   not hold", "Could not verify", "Missing witnesses". Do not replace them
   with your own ("Findings", "Rejected findings", "Summary"). "Diagnosis"
   appears only for a failure; every other section is always present, with
   the user's word for "None" when empty. The header names which witnesses
   answered by model (S sonnet, O opus, F fable). Every finding, in every
   section and whatever its severity, has its location and the quoted
   evidence; a confirmed one also has one proposed fix (when the choice is
   the user's, recommend one option rather than listing several). A prose
   summary that points to the file is not the report.

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
