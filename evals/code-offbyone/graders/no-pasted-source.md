---
type: regex
target: trace
pattern: '"name":\s*"(Agent|Write|Bash)",\s*"input":\s*\{[^\n]*timedelta'
match: not_contains
arm: with-only
---
