---
type: regex
target: trace
pattern: '"name":\s*"(?:Agent)",\s*"input":\s*\{[^\n]*timedelta|"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*brief\.md")[^\n]*timedelta'
match: not_contains
arm: with-only
---
