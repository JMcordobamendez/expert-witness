---
type: regex
target: trace
pattern: '"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*after\.txt")[^\n]*NOTES\.txt'
arm: with-only
---
