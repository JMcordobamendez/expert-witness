---
type: regex
target: trace
pattern: '"name":\s*"(Agent|Write|Bash)",\s*"input":\s*\{[^\n]*umask'
match: not_contains
arm: both
---
