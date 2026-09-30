---
type: regex
target: trace
pattern: '"name":\s*"(Agent|Bash)",\s*"input":\s*\{[^\n]*umask|"name":\s*"Write",\s*"input":\s*\{\s*"file_path":\s*"[^"]*brief\.md"[^\n]*umask'
match: not_contains
arm: both
---
