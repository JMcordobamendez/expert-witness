#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir repo && cp "$here/fixture/plan.md" repo/
cd repo && git init -q && git -c user.email=dev@example.com -c user.name=dev add -A && git -c user.email=dev@example.com -c user.name=dev commit -qm "Email migration plan"
