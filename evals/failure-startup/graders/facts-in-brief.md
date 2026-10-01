---
type: regex
target: trace
pattern: '"name":\s*"(?:Agent)",\s*"input":\s*\{[^\n]*?Tried:(?:(?!\\n)[^\n])*[Rr]einstall|"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*brief\.md")[^\n]*?Tried:(?:(?!\\n)[^\n])*[Rr]einstall'
arm: with-only
---
