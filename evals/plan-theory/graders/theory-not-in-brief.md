---
type: regex
target: trace
pattern: '"name":\s*"(?:Agent)",\s*"input":\s*\{[^\n]*\b[Ll]ock|"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*brief\.md")[^\n]*\b[Ll]ock'
match: not_contains
arm: both
---
