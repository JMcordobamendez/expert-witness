---
type: regex
target: trace
pattern: '"name":\s*"(?:Agent)",\s*"input":\s*\{[^\n]*(?:\b[Ll]ock|LOCK|[Ss]tep 5|2\.3|[Mm]illion|NOT NULL|real risk|rest is fine)|"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*brief\.md")[^\n]*(?:\b[Ll]ock|LOCK|[Ss]tep 5|2\.3|[Mm]illion|NOT NULL|real risk|rest is fine)'
match: not_contains
arm: both
---
