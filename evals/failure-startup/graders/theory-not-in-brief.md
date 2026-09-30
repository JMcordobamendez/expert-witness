---
type: regex
target: trace
pattern: '"name":\s*"(?:Agent|Bash)",\s*"input":\s*\{[^\n]*umask|"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*brief\.md")[^\n]*umask'
match: not_contains
arm: both
---
