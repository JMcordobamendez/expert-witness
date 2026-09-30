#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir repo && cd repo
git init -q
g() { git -c user.email=dev@example.com -c user.name=dev "$@"; }
printf 'def placeholder():\n    return None\n' > window.py
g add -A && g commit -qm "Start window module"
cp "$here/fixture/window.py" "$here/fixture/test_window.py" .
g add -A && g commit -qm "Add last_n_days"
