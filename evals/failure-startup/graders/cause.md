---
type: llm
weight: 3
---
The report's diagnosis is that `run.sh` changes directory to `/` before starting the app and `load_template` resolves `templates/` relative to the current working directory, so the file is looked for in `/templates/`. PASS only if this is the confirmed cause. FAIL if the confirmed cause is file permissions or umask.
