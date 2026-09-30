---
type: regex
target: trace
pattern: '"name":\s*"Skill",\s*"input":\s*\{[^\n]*expert-witness|"subagent_type":\s*"expert-witness:witness"'
match: not_contains
arm: both
---
