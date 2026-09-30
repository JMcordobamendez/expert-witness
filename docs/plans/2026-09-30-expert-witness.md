# expert-witness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Claude Code plugin whose skill sends a subject (code, plan, document or failure) to three blind witness subagents on Sonnet, Opus and Fable, then verifies and reports their findings.

**Architecture:** Pure-markdown plugin: one agent definition (`agents/witness.md`) dispatched three times with different `model` values, and one skill (`skills/expert-witness/`) that writes the brief, dispatches, snapshots, clusters, verifies and reports. It is tested with `claude plugin eval`: seeded-defect cases, graded with and without the plugin (the no-plugin arm is the RED baseline required by `superpowers:writing-skills`).

**Tech Stack:** Claude Code 2.1.285 plugins (`.claude-plugin/plugin.json`, `marketplace.json`), `claude plugin validate`, `claude plugin eval` (cases as `case.yaml` + `graders/*.md` + `scaffold.sh`), git, Python 3 only inside test fixtures.

**Spec:** `docs/specs/2026-09-30-expert-witness-design.md`

## Global Constraints

- Every file in the repo is in English. The final report the skill produces is written in the user's language.
- The product (agent, skill, templates) has no scripts, no dependencies, no API keys, no external model providers. Scripts are allowed only under `evals/` as test fixtures.
- Witness roster, exactly: `sonnet`, `opus`, `fable`. Same agent definition for all three.
- Witnesses diagnose and propose; they never apply fixes.
- The run directory is never inside the reviewed repo or next to the reviewed file.
- For a `failure`, the brief carries facts only: no hypothesis from the orchestrator, not even marked as unverified.
- No "approve my synthesis" rounds. The only follow-up is one fresh witness on one disputed point, blind to who said what.
- License MIT. Plugin name, marketplace name and skill name: `expert-witness`. Agent name: `witness` (dispatched as `expert-witness:witness`).
- Commits: author `JMcordobamendez <79694677+JMcordobamendez@users.noreply.github.com>` (already set in the repo's git config); every commit message ends with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_018sEc4ryqriprzoMZEF8pvu
  ```
- Do not create the GitHub repo or push before Task 6.

## Facts verified before writing this plan (2026-09-30)

- A plugin skill at `skills/expert-witness/SKILL.md` is invoked by typing `/expert-witness`; the Skill tool records it as `expert-witness:expert-witness`.
- A plugin agent at `agents/witness.md` is dispatched with `subagent_type: "expert-witness:witness"`, and the Agent tool's `model` parameter applies when the agent file sets no `model`.
- `fable` is accepted as a subagent `model` on this account.
- `claude -p` works when launched from inside a Claude Code session.
- `claude plugin eval` runs each case in a fresh empty workspace. `context.scaffold_script` (only with `--scaffold`) runs first in that workspace; it finds its own case directory with `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`. Plugin agents dispatch fine inside eval runs when `Agent` is in `allowed_tools`.
- Granting `Bash` in eval runs needs the sandbox backend; on this WSL `bubblewrap` is installed and `socat` is not. Until Josemi installs `socat`, cases must run without `Bash` (see Task 1 Step 4).
- Graders: `regex` (targets `last_message` or `trace`, `match: not_contains`), `tool_used` (`input_match`, `min`, `max`), `file_exists`, `llm` (rubric in the body, `focus: last_message | trace | {source: file, path: glob}`), `arm: with-only | both`. The llm judge sees only the first 12 and last 12 trace messages, so anything mid-run is checked with `regex` on `trace`.

## Review Focus

1. **Subject outside git** (a report in some folder): the before/after snapshot must fall back to file hashes, not be skipped silently. Pinned by the `document-report` case, whose scaffold does not create a git repo.
2. **The user's own request contains a theory** ("I think it's the cache"): the request is quoted verbatim (it is the user's), and witnesses treat it as an unverified claim and say so. Pinned by a grader in `failure-startup`.
3. **A witness answers in free prose, ignoring the output contract**: it is retried once, then reported as missing; the run does not silently count it. Pinned by the `witness-contract` case (the contract fields are graded).
4. **Large subject** (a whole repo): the brief points at it and never pastes it. Pinned by a `regex` grader in `code-offbyone` that the brief does not contain the source code.
5. **Clean material**: witnesses must not invent findings to have something to say. Pinned by the `clean-control` case.

---

## File Structure

```
expert-witness/
├── .claude-plugin/plugin.json        # Task 1
├── .claude-plugin/marketplace.json   # Task 1
├── .gitignore                        # Task 1 (evals/results/)
├── LICENSE                           # Task 1 (MIT)
├── README.md                         # Task 1 stub, Task 6 full
├── agents/witness.md                 # Task 4
├── skills/expert-witness/SKILL.md    # Task 5
├── skills/expert-witness/brief-template.md   # Task 5
├── skills/expert-witness/report-template.md  # Task 5
├── evals/
│   ├── code-offbyone/     # Task 2
│   ├── plan-contradiction/# Task 2
│   ├── document-report/   # Task 2
│   ├── failure-startup/   # Task 2
│   ├── clean-control/     # Task 2
│   └── witness-contract/  # Task 4
└── docs/
    ├── specs/…            # exists
    ├── plans/…            # this file
    ├── baseline.md        # Task 3
    └── results.md         # Task 5
```

Each eval case directory holds `case.yaml`, `scaffold.sh`, `fixture/`, `graders/*.md` and `expected.md`. `expected.md` is for humans and the plan; it is never copied into the workspace, so no run can see it.

---

### Task 1: Plugin skeleton that validates

**Files:**
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.gitignore`, `LICENSE`, `README.md`

**Interfaces:**
- Produces: a plugin named `expert-witness` that `claude plugin validate --strict .` accepts and `claude plugin eval .` can load.

- [ ] **Step 1: Write the manifests**

`.claude-plugin/plugin.json`:
```json
{
  "name": "expert-witness",
  "version": "0.1.0",
  "description": "Blind multi-model review for Claude Code: three witnesses on Sonnet, Opus and Fable review code, plans, documents or failures without the session's context, and the orchestrator verifies every finding.",
  "author": { "name": "JMcordobamendez" },
  "homepage": "https://github.com/JMcordobamendez/expert-witness",
  "repository": "https://github.com/JMcordobamendez/expert-witness",
  "license": "MIT",
  "keywords": ["review", "audit", "multi-model", "code-review", "debugging", "confirmation-bias"]
}
```

`.claude-plugin/marketplace.json`:
```json
{
  "name": "expert-witness",
  "description": "Marketplace for the expert-witness plugin.",
  "owner": { "name": "JMcordobamendez" },
  "plugins": [
    {
      "name": "expert-witness",
      "source": "./",
      "description": "Blind multi-model review: three witnesses, verified findings.",
      "version": "0.1.0"
    }
  ]
}
```

`.gitignore`:
```
evals/results/
```

`LICENSE`: the standard MIT text, `Copyright (c) 2026 JMcordobamendez`.

`README.md` (stub, completed in Task 6):
```markdown
# expert-witness

Blind multi-model review for Claude Code. Work in progress; see `docs/specs/`.
```

- [ ] **Step 2: Validate**

Run: `cd /home/josemi/Software/Repos/expert-witness && claude plugin validate --strict .`
Expected: `✔ Validation passed` with no warnings. If a warning names a missing field, add that field (only fields the validator names).

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin .gitignore LICENSE README.md
git commit -m "Plugin skeleton: manifests, license, readme stub"
```

- [ ] **Step 4: Record the Bash decision**

Run: `which socat bwrap`
- If both exist, every eval case in this plan lists `Bash` in `allowed_tools` and every `claude plugin eval` command gets `--allow-tools Bash`.
- If `socat` is missing, drop `Bash` from `allowed_tools` in every case and leave out `--allow-tools Bash`; write one line in `docs/results.md` saying the suite ran without Bash and why. The before/after snapshot then cannot run `git status`; the skill must fall back to reading files (Review Focus 1), which the suite still exercises.

---

### Task 2: The seeded-defect eval suite

**Files:**
- Create: `evals/{code-offbyone,plan-contradiction,document-report,failure-startup,clean-control}/` each with `case.yaml`, `scaffold.sh`, `fixture/…`, `graders/*.md`, `expected.md`

**Interfaces:**
- Consumes: the plugin from Task 1.
- Produces: `claude plugin eval . --scaffold --trust-plugin --no-publish` runs five cases. Later tasks change no case except to fix a case bug, which must be recorded in `docs/results.md`.

Common to every `case.yaml` (copy it in full into each case; only `name`, `description`, `tags`, `execution.prompt` differ):
```yaml
schema_version: "1.1"
name: <case>
description: <one line>
tags: [<kind>]
runs: 3
context:
  scaffold_script: scaffold.sh
execution:
  model: opus
  max_turns: 80
  timeout_seconds: 2400
  allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill, Agent, TodoWrite]
  prompt: |
    <case prompt>
```
(Drop `Bash` per Task 1 Step 4.)

Common structural graders, one file each, in every case's `graders/` except `clean-control` where noted:

`graders/witnesses-dispatched.md`:
```markdown
---
type: tool_used
tool: Agent
input_match: "expert-witness:witness"
min: 3
arm: with-only
---
```

`graders/fable-used.md`:
```markdown
---
type: regex
target: trace
pattern: '"model":\s*"fable"'
arm: with-only
---
```

`graders/report-shape.md`:
```markdown
---
type: llm
weight: 1
---
The final message is a review report that (a) states which reviewers answered, (b) lists findings with, for each one, a location, the quoted evidence and a proposed fix, and (c) separates findings it confirmed from findings it rejected or could not verify. PASS only if all three hold.
```

- [ ] **Step 1: `code-offbyone`**

`fixture/window.py` (the second commit introduces `last_n_days`):
```python
from datetime import date, timedelta


def last_n_days(entries, n, today):
    """Return the entries dated within the last n days, today included.

    An entry dated exactly n days before today is included.
    """
    start = today - timedelta(days=n)
    return [e for e in entries if start < e["date"] <= today]
```

`fixture/test_window.py`:
```python
from datetime import date

from window import last_n_days


def test_keeps_recent_and_drops_old():
    today = date(2026, 9, 30)
    entries = [
        {"date": date(2026, 9, 29), "v": 1},
        {"date": date(2026, 9, 10), "v": 2},
        {"date": date(2026, 8, 1), "v": 3},
    ]
    assert [e["v"] for e in last_n_days(entries, 7, today)] == [1]


def test_today_is_included():
    today = date(2026, 9, 30)
    assert last_n_days([{"date": today, "v": 1}], 7, today) == [{"date": today, "v": 1}]
```

`scaffold.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir repo && cd repo
git init -q
g() { git -c user.email=dev@example.com -c user.name=dev "$@"; }
printf 'def placeholder():\n    return None\n' > window.py
g add -A && g commit -qm "Start window module"
cp "$here/fixture/window.py" "$here/fixture/test_window.py" .
g add -A && g commit -qm "Add last_n_days"
```

`execution.prompt`:
```
Please get me an independent review of the last commit in ./repo (it adds last_n_days). I want to merge it today.
```

`graders/offbyone.md`:
```markdown
---
type: llm
weight: 3
---
The report presents as a confirmed finding that `last_n_days` excludes the entry dated exactly n days before today (the `start < e["date"]` comparison should be `<=`), contradicting its own docstring, and that no test covers that boundary. PASS only if this boundary bug is reported as confirmed, not as rejected or unverified.
```

`graders/no-pasted-source.md` (Review Focus 4):
```markdown
---
type: regex
target: trace
pattern: '"name":\s*"(Agent|Write|Bash)",\s*"input":\s*\{[^}]*timedelta'
match: not_contains
arm: with-only
---
```

`expected.md`: "Planted: boundary off-by-one in `last_n_days` (`<` instead of `<=`), docstring says the boundary is included, tests pass because none covers it."

- [ ] **Step 2: `plan-contradiction`**

`fixture/spec.md`:
```markdown
# Archive service — design

## 1. Purpose
Users keep their monthly bank statements and invoices in one archive.

## 2. Accounts
One account per household; up to five members.

## 3. Uploads
Uploads are limited to 10 MB per file. Larger files are rejected with a clear message.

## 4. Storage
Files are stored encrypted at rest; keys are per household.

## 5. Search
Full-text search over PDF text, updated within one minute of upload.

## 6. Retention
Files are kept until the household deletes them.

## 7. Monthly archive
At the end of each month, members upload the month's combined archive (a single PDF, typically 40–60 MB) so the whole month can be restored in one step.

## 8. Out of scope
Mobile apps; sharing outside the household.
```

`scaffold.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir repo && cp "$here/fixture/spec.md" repo/
cd repo && git init -q && git -c user.email=dev@example.com -c user.name=dev add -A && git -c user.email=dev@example.com -c user.name=dev commit -qm "Spec draft"
```

`execution.prompt`:
```
I've just finished the spec in ./repo/spec.md. Have it reviewed independently before I write the implementation plan.
```

`graders/contradiction.md`:
```markdown
---
type: llm
weight: 3
---
The report presents as a confirmed finding that section 3 (10 MB upload limit) contradicts section 7 (a monthly archive of 40–60 MB uploaded as a single PDF). PASS only if this contradiction is reported and confirmed.
```

`expected.md`: "Planted: §3 10 MB limit vs §7 40–60 MB single-file archive."

- [ ] **Step 3: `document-report`** (no git repo: Review Focus 1)

`fixture/report.md`:
```markdown
# Q-review 2025 — sales

Prepared for the board.

## Summary
Sales grew in every quarter of 2025, reaching 1.42 M€ in Q4.

## Price change
We raised prices by 8% at the start of Q2. Q2 sales rose to 1.21 M€, which shows the price increase caused the growth.

## Recommendation
Raise prices again by 8% in Q1 2026.
```

`fixture/sales-2025.csv`:
```
quarter,sales_eur
Q1,1130000
Q2,1210000
Q3,1170000
Q4,1420000
```

`scaffold.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir board && cp "$here/fixture/report.md" "$here/fixture/sales-2025.csv" board/
```

`execution.prompt`:
```
A colleague wrote ./board/report.md for the board; the data it is based on is ./board/sales-2025.csv. Critique it in detail so it can be improved.
```

`graders/false-claim.md`:
```markdown
---
type: llm
weight: 3
---
The report confirms that the claim "Sales grew in every quarter of 2025" is contradicted by the data (Q3, 1.17 M€, is below Q2, 1.21 M€). PASS only if this is reported as confirmed.
```

`graders/non-sequitur.md`:
```markdown
---
type: llm
weight: 2
---
The report confirms that the conclusion "the price increase caused the growth" does not follow from the data (one quarter's rise after a price change is not evidence of causation), and proposes concrete replacement wording or analysis. PASS only if both hold.
```

`expected.md`: "Planted: false 'every quarter' claim (Q3 dip); causal conclusion from one data point."

- [ ] **Step 4: `failure-startup`** (facts vs. theory)

`fixture/app/server.py`:
```python
import os


def load_template(name):
    path = os.path.join("templates", name)
    with open(path) as f:
        return f.read()


def main():
    page = load_template("index.html")
    print("serving", len(page), "bytes")


if __name__ == "__main__":
    main()
```

`fixture/app/templates/index.html`:
```html
<!doctype html><title>ok</title><p>ok</p>
```

`fixture/run.sh`:
```bash
#!/usr/bin/env bash
# Start script used by the service manager.
here="$(cd "$(dirname "$0")" && pwd)"
cd /
exec python3 "$here/app/server.py"
```

(The script path is resolved before `cd /`, so Python finds `server.py`; `templates/` is then resolved against `/`.)

`fixture/logs/service.log`:
```
2026-09-30 07:01:12 starting app
Traceback (most recent call last):
  File "/srv/app/app/server.py", line 16, in <module>
    main()
  File "/srv/app/app/server.py", line 11, in main
    page = load_template("index.html")
  File "/srv/app/app/server.py", line 6, in load_template
    with open(path) as f:
FileNotFoundError: [Errno 2] No such file or directory: 'templates/index.html'
2026-09-30 07:01:12 app exited with status 1
2026-09-30 07:02:40 (after reinstalling dependencies) starting app
FileNotFoundError: [Errno 2] No such file or directory: 'templates/index.html'
2026-09-30 07:02:40 app exited with status 1
```

`scaffold.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$here/fixture" repo && chmod +x repo/run.sh
cd repo && git init -q && git -c user.email=dev@example.com -c user.name=dev add -A && git -c user.email=dev@example.com -c user.name=dev commit -qm "App"
```

`execution.prompt` (the session notes simulate the orchestrator's own unverified theory; the user's request is the last line):
```
Session notes so far (yours, from earlier in this conversation): you looked at this for a while and your working theory is that the umask on the templates folder makes index.html unreadable to the service user. You have not verified it.

User: the app in ./repo won't start when the service manager runs ./repo/run.sh — logs are in ./repo/logs/service.log. Reinstalling dependencies didn't help. Get me an independent diagnosis.
```

`graders/cause.md`:
```markdown
---
type: llm
weight: 3
---
The report's diagnosis is that `run.sh` changes directory to `/` before starting the app and `load_template` resolves `templates/` relative to the current working directory, so the file is looked for in `/templates/`. PASS only if this is the confirmed cause. FAIL if the confirmed cause is file permissions or umask.
```

`graders/theory-not-in-brief.md` (arm both: the baseline must not leak it either):
```markdown
---
type: regex
target: trace
pattern: '"name":\s*"(Agent|Write|Bash)",\s*"input":\s*\{[^}]*umask'
match: not_contains
arm: both
---
```

`graders/facts-in-brief.md`:
```markdown
---
type: regex
target: trace
pattern: '"name":\s*"(Agent|Write|Bash)",\s*"input":\s*\{[^}]*reinstall'
arm: with-only
---
```

`expected.md`: "Planted: cwd-relative template path + `cd /` in run.sh. False theory handed to the orchestrator: umask. The brief must carry the reinstall result (fact) and not the umask theory."

- [ ] **Step 5: `clean-control`**

`fixture/clamp.py`:
```python
def clamp(value, low, high):
    """Return value limited to the closed range [low, high].

    Raises ValueError if low > high.
    """
    if low > high:
        raise ValueError(f"low ({low}) is greater than high ({high})")
    return max(low, min(value, high))
```

`fixture/test_clamp.py`:
```python
import pytest

from clamp import clamp


@pytest.mark.parametrize(
    "value, low, high, expected",
    [(5, 0, 10, 5), (-1, 0, 10, 0), (11, 0, 10, 10), (0, 0, 10, 0), (10, 0, 10, 10), (3, 3, 3, 3)],
)
def test_clamp(value, low, high, expected):
    assert clamp(value, low, high) == expected


def test_rejects_inverted_range():
    with pytest.raises(ValueError):
        clamp(1, 5, 0)
```

`scaffold.sh`: same shape as `code-offbyone` (first commit a placeholder `clamp.py`, second commit these two files, message "Add clamp").

`execution.prompt`:
```
Please get me an independent review of the last commit in ./repo (it adds clamp). I want to merge it today.
```

`graders/no-invented.md` (instead of a planted-defect grader):
```markdown
---
type: llm
weight: 3
---
The code under review is correct and fully tested. PASS if the report confirms no finding of severity critical or important (minor or style notes are acceptable, and so are rejected findings listed as rejected). FAIL if any critical or important finding is presented as confirmed.
```

`expected.md`: "No planted defect. Measures invented findings."

- [ ] **Step 6: Check the fixtures behave as planted**

Run, for each case, the scaffold in a temp dir and check:
```bash
for c in code-offbyone plan-contradiction document-report failure-startup clean-control; do
  d=$(mktemp -d) && (cd "$d" && bash /home/josemi/Software/Repos/expert-witness/evals/$c/scaffold.sh) && echo "$c ok: $(ls "$d")"
done
d=$(mktemp -d) && (cd "$d" && bash /home/josemi/Software/Repos/expert-witness/evals/code-offbyone/scaffold.sh && cd repo && python3 -m pytest -q)
d=$(mktemp -d) && (cd "$d" && bash /home/josemi/Software/Repos/expert-witness/evals/clean-control/scaffold.sh && cd repo && python3 -m pytest -q)
d=$(mktemp -d) && (cd "$d" && bash /home/josemi/Software/Repos/expert-witness/evals/failure-startup/scaffold.sh && "$d/repo/run.sh"; echo "exit=$?")
```
Expected: every scaffold prints `ok`; both pytest runs pass (2 passed, 7 passed); `run.sh` fails with `FileNotFoundError: ... 'templates/index.html'` and a non-zero exit. If pytest is missing, `python3 -m pip install --user pytest` first.

- [ ] **Step 7: Validate and commit**

Run: `claude plugin validate --strict .` → passes.
```bash
git add evals
git commit -m "Eval suite: five seeded-defect cases and a clean control"
```

---

### Task 3: RED baseline — the suite without the skill

**Files:**
- Create: `docs/baseline.md`

**Interfaces:**
- Consumes: Tasks 1–2. There is still no agent and no skill.

- [ ] **Step 1: Run the suite**

Run:
```bash
cd /home/josemi/Software/Repos/expert-witness
claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp --allow-tools Bash --json docs/.baseline.json
```
(Without `--allow-tools Bash` per Task 1 Step 4.)
Expected: it completes; scores are low. Both arms are equivalent because the plugin has no skill yet.

- [ ] **Step 2: Read what the orchestrator did**

For each case, open the kept traces (paths in `docs/.baseline.json`, `tracePath`) and record, in `docs/baseline.md`, one short section per case:
- did it review on its own or dispatch reviewers, and with which models;
- what it passed to reviewers (quote the relevant part of the dispatch prompt);
- for `failure-startup`: did the umask theory reach any reviewer or file;
- did it check findings against the source before reporting;
- which planted defects it found, and whether `clean-control` got invented findings;
- score per case.

Also check the `regex` graders against a real trace: for each pattern in `evals/*/graders/*.md` with `target: trace`, take one kept trace and confirm with `grep -cE` that the tool-call shape the pattern assumes (`"name": "Agent", "input": {`) is how tool calls actually appear in the trace. If the shape differs, fix the patterns now and record it in `docs/baseline.md`.

End with a list headed "Failures the skill must fix", one line each, taken only from what the traces show.

- [ ] **Step 3: Commit**

```bash
git add docs/baseline.md
git commit -m "Baseline: how the orchestrator reviews without expert-witness"
```
(`docs/.baseline.json` stays uncommitted: add `docs/.baseline.json` to `.gitignore` in this commit.)

---

### Task 4: The witness agent

**Files:**
- Create: `agents/witness.md`
- Create: `evals/witness-contract/` (`case.yaml`, `scaffold.sh`, `graders/*.md`, `expected.md`)

**Interfaces:**
- Consumes: the `code-offbyone` fixture (copied, not referenced).
- Produces: `expert-witness:witness`, dispatched with `model` ∈ {`sonnet`, `opus`, `fable`}; its prompt names a brief file and a report path; it writes the report there and returns a one-line summary.

- [ ] **Step 1: Write the failing contract case**

`evals/witness-contract/scaffold.sh`: builds `repo/` exactly like `code-offbyone`, then writes `brief.md` outside `repo/`:
```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$here/../code-offbyone/scaffold.sh"
mkdir run
cat > run/brief.md <<'EOF'
# Brief

Kind: code

Request (verbatim):
> Please review the last commit in ./repo (it adds last_n_days). I think the problem is in how it parses dates.

Material:
- Repository: ./repo — see the change with `git -C repo show HEAD`.
EOF
```

`case.yaml` (as the common template, with `runs: 3` and this prompt):
```
Dispatch the expert-witness:witness agent once, with model sonnet, telling it: "Your brief is ./run/brief.md. Write your report to ./run/witness-sonnet.md." Then print ./run/witness-sonnet.md verbatim as your final message, with nothing added.
```

Graders:

`graders/contract.md`:
```markdown
---
type: llm
weight: 3
---
The final message is a witness report in which every finding has all of these labelled fields: Severity (critical, important or minor), Location, Evidence (a verbatim quote), Problem, Proposal, Confidence, Would be refuted by. It also has a section "Unintended consequences" and a section "Could not check". PASS only if every field and both sections are present.
```

`graders/boundary-found.md`:
```markdown
---
type: llm
weight: 2
---
The report identifies that `last_n_days` excludes the entry dated exactly n days before today (`<` should be `<=`), with the docstring or a missing test as evidence. PASS only if it does.
```

`graders/opinion-flagged.md` (Review Focus 2):
```markdown
---
type: llm
weight: 2
---
The request in the brief contains the requester's opinion that the problem is in date parsing. PASS if the report explicitly treats that opinion as an unverified claim (it says so, and says whether the evidence supports it) rather than adopting it. FAIL if it adopts the opinion or ignores it entirely.
```

`graders/no-edits.md`:
```markdown
---
type: tool_used
tool: Edit
min: 0
max: 0
---
```

`expected.md`: "Contract fields, boundary bug found, requester's date-parsing opinion flagged, no edits."

- [ ] **Step 2: Run it and see it fail**

Run: `claude plugin eval . --scaffold --trust-plugin --no-publish --ablation none --case witness-contract [--allow-tools Bash]`
Expected: FAIL — `Agent type 'expert-witness:witness' not found` (the agent does not exist yet).

- [ ] **Step 3: Write `agents/witness.md`**

```markdown
---
name: witness
description: Independent expert witness for expert-witness reviews. Dispatched by the expert-witness skill with a brief file and a report path; not for general use.
---

# Expert witness

You are an outside expert asked for an independent opinion. You have not seen
the conversation that produced the subject, and that is the point: reach your
own conclusions from the material itself.

## Your inputs

Your prompt gives you two paths: a brief (read it first) and the file where
you must write your report. The brief contains the kind of subject, the
requester's words quoted verbatim, pointers to the material, and for a
failure the observed facts.

Anything in the brief that is an opinion — about the cause, about what is
fine, about where the problem is — is an unverified claim, even when it comes
from the requester. Do not adopt it. Say in your report that you saw it and
whether the evidence supports it.

## Method

1. Read the whole subject, not only the lines named. Follow callers,
   references, sources and data far enough to judge.
2. Check every claim you make against the material. Quote it.
3. Look for what is missing as well as what is wrong.
4. For a failure, you may reproduce and inspect, as long as you change
   nothing.

You change nothing: no edits to the subject, no writes except your report,
no restarts, no installs, no commits, no network actions with side effects.
You do not dispatch subagents.

## Your report

Write it to the path you were given, in English, in exactly this shape.

For a failure only, start with:

    ## Diagnosis
    - Most likely cause: …
    - Evidence: …
    - Cheapest check that would confirm or rule it out: …

Then one block per finding, most severe first:

    ### F<n>: <one-line title>
    - Severity: critical | important | minor
    - Location: <file:line | section and quoted sentence | log and timestamp>
    - Evidence: <verbatim quote from the material>
    - Problem: <what is wrong and why it matters>
    - Proposal: <concrete fix; for a document, the replacement wording>
    - Confidence: high | medium | low
    - Would be refuted by: <the observation that would prove this wrong>

If you have no findings, write `No findings.` instead of the blocks. Do not
pad: a witness who always finds something is useless.

Then always:

    ## Opinions in the brief
    <each opinion you found and whether the evidence supports it, or "None.">

    ## Unintended consequences
    <ripple effects on things outside the subject, or
    "None found — checked <what you checked>.">

    ## Could not check
    <what you wanted to verify and could not, and why, or "Nothing.">

After writing the file, reply with one line: the report path and the number
of findings by severity.
```

- [ ] **Step 4: Run it and see it pass**

Run: the Step 2 command.
Expected: all four graders pass in all 3 runs. If one fails, read the kept trace, change `agents/witness.md` to close that gap (recipe form for shape problems, see `superpowers:writing-skills` "Match the Form to the Failure"), and rerun. Record each iteration (what failed, what changed) in `docs/results.md` under "Witness".

- [ ] **Step 5: Commit**

```bash
git add agents/witness.md evals/witness-contract docs/results.md
git commit -m "Witness agent with a strict report contract"
```

---

### Task 5: The orchestrating skill

**Files:**
- Create: `skills/expert-witness/SKILL.md`, `skills/expert-witness/brief-template.md`, `skills/expert-witness/report-template.md`
- Modify: `docs/results.md`

**Interfaces:**
- Consumes: `expert-witness:witness` from Task 4 (brief path in, report file out, one-line reply).
- Produces: `/expert-witness <subject>`; also auto-triggered by its description.

- [ ] **Step 1: Confirm RED for this task**

The five Task 2 cases already fail (Task 3). Nothing to write here; `docs/baseline.md` is the failing test.

- [ ] **Step 2: Write `brief-template.md`**

```markdown
# Brief

Kind: <code | plan | document | failure>

## Request (verbatim)
> <the user's words, quoted exactly; never paraphrased>

## Material
- <path, commit range, URL or command to see each piece>

## Sources to check against
<document only: data files, references, or "None given.">

## Observed facts
<failure only. Each line is something that was seen, with where it was seen:
- Symptom: …
- How to reproduce: …
- Errors and logs (verbatim): …
- Tried: <action> → <what happened>
Nothing else goes here.>

## Your report
Write it to: <run directory>/witness-<model>.md
```

- [ ] **Step 3: Write `report-template.md`**

```markdown
# Expert witness report — <subject>

Kind: <kind> · Witnesses: <S/O/F that answered> · Run: <run directory>

## Changes made by witnesses
<only if the after snapshot differs: what changed and where>

## Diagnosis
<failure only: the confirmed cause, or the competing ones with their evidence>

## Confirmed findings
<most severe first; each: title, seen by (S/O/F), location, evidence, problem, proposal>

## Disagreements
<where witnesses contradicted each other: both sides and your reading>

## Does not hold
<rejected findings, each with seen by and why it does not hold>

## Could not verify
<findings you could not check, and why>

## Missing witnesses
<who failed and how; "insufficient" if only one answered>
```

(The report is written in the user's language; the headings above are translated with it.)

- [ ] **Step 4: Write `SKILL.md`**

```markdown
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
   file.

2. **Brief.** Copy `brief-template.md` to `<run>/brief.md` and fill every
   slot. The request is the user's own words, quoted exactly. Material is
   pointers, never pasted content.

   For a failure, "Observed facts" holds only things that were seen: the
   symptom, how to reproduce it, errors and logs verbatim, and each thing
   tried with what happened. Your theories go nowhere in the brief.

3. **Before snapshot.** In a git repo: `git status --porcelain` and
   `git rev-parse HEAD`. Otherwise: a hash of every file the brief points at.
   Save it as `<run>/before.txt`.

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
```

- [ ] **Step 5: Validate**

Run: `claude plugin validate --strict .` → passes.

- [ ] **Step 6: Run the suite (GREEN)**

Run:
```bash
claude plugin eval . --scaffold --trust-plugin --no-publish -j 4 --keep-temp [--allow-tools Bash] --json docs/.results.json
```
Expected: every case scores 1.0 in the with-plugin arm; `theory-not-in-brief` passes; `clean-control` passes; delta over baseline is positive in every case where the baseline failed.

- [ ] **Step 7: REFACTOR until green, then record**

For each failing grader: read the kept trace, find the exact place the orchestrator or a witness went wrong, change the skill or agent (never the grader, unless the grader is wrong — then say so in `docs/results.md` with the evidence), and rerun only that case with `--case <name>`. When all pass, rerun the full suite once. Write `docs/results.md`: final score table (with and without), each iteration (what failed, the trace evidence, what changed), and any case bug found.

- [ ] **Step 8: Commit**

```bash
git add skills docs/results.md .gitignore
git commit -m "Orchestrating skill: blind brief, three witnesses, verified report"
```

---

### Task 6: README and publish

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above, with the suite green.

- [ ] **Step 1: Write the README**

Sections, in this order:
1. What it is (two sentences) and why (confirmation bias of a session reviewing its own work).
2. Install: `/plugin marketplace add JMcordobamendez/expert-witness` then `/plugin install expert-witness@expert-witness`.
3. Use: `/expert-witness <what to review>`, the four kinds with one example request each, and when Claude launches it by itself (the three moments, one-line announcement).
4. How it works: brief (verbatim request, pointers, facts only), three witnesses on Sonnet, Opus and Fable, snapshot, clustering, verification, report sections.
5. Cost: each run is three full subagent reviews plus verification.
6. Note on Fable: why a creative-writing model is on a technical panel (never alone; every finding verified).
7. Limits: witnesses have full tool access and are told not to change anything; the snapshot detects breaches, it does not prevent them. Everything stays inside Anthropic (no external providers).
8. Testing: `claude plugin eval . --scaffold --trust-plugin`, what the cases plant, the with/without scores from `docs/results.md`.
9. Credits: inspired by AltimateAI/claude-consensus; license MIT.

- [ ] **Step 2: Validate and commit**

Run: `claude plugin validate --strict .`
```bash
git add README.md
git commit -m "README: install, use, how it works, limits, tests"
```

- [ ] **Step 3: Create the public repo and push**

```bash
gh repo create JMcordobamendez/expert-witness --public --description "Blind multi-model review for Claude Code: three witnesses (Sonnet, Opus, Fable), verified findings." --source . --push
```
Expected: the repo URL is printed and `main` is pushed.

- [ ] **Step 4: Install from GitHub in a clean session and smoke-test**

Run:
```bash
claude plugin marketplace add JMcordobamendez/expert-witness
claude plugin install expert-witness@expert-witness
claude plugin details expert-witness
```
Expected: the plugin lists one skill (`expert-witness`) and one agent (`witness`). Then run the `plan-contradiction` case against the installed plugin: `claude plugin eval expert-witness@expert-witness --eval-dir evals --case plan-contradiction --scaffold --trust-plugin --no-publish`; expected score 1.0.
```

