---
type: regex
target: trace
pattern: '"name":\s*"Agent",\s*"input":\s*\{[^\n]*timedelta|"name":\s*"Write",\s*"input":\s*\{\s*"file_path":\s*"[^"]*brief\.md"[^\n]*timedelta'
match: not_contains
arm: with-only
---
