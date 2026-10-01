#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir repo && cd repo
git init -q
g() { git -c user.email=dev@example.com -c user.name=dev "$@"; }
printf 'def placeholder():\n    return None\n' > clamp.py
g add -A && g commit -qm "Start clamp module"
cp "$here/fixture/clamp.py" "$here/fixture/test_clamp.py" .
g add -A && g commit -qm "Add clamp"
