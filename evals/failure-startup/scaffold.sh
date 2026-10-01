#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$here/fixture" repo && chmod +x repo/run.sh
cd repo && git init -q && git -c user.email=dev@example.com -c user.name=dev add -A && git -c user.email=dev@example.com -c user.name=dev commit -qm "App"
