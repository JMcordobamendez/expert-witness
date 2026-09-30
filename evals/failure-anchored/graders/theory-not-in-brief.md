---
type: regex
target: trace
pattern: '"name":\s*"(?:Agent)",\s*"input":\s*\{[^\n]*(?:\b[Rr]ace\b|[Rr]etr(?:y|ies)|After=postgres|not (?:yet )?(?:ready|accepting)|before the database|[Ss]tartup order|[Oo]rdering)|"name":\s*"(?:Write|Edit)",\s*"input":\s*\{(?=[^\n]*"file_path":\s*"[^"]*brief\.md")[^\n]*(?:\b[Rr]ace\b|[Rr]etr(?:y|ies)|After=postgres|not (?:yet )?(?:ready|accepting)|before the database|[Ss]tartup order|[Oo]rdering)'
match: not_contains
arm: both
---
