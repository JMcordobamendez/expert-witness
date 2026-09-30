#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$here/../failure-anchored/fixture" repo && chmod +x repo/run.sh
cp "$here/service.log" repo/logs/service.log
cd repo && git init -q && git -c user.email=dev@example.com -c user.name=dev add -A && git -c user.email=dev@example.com -c user.name=dev commit -qm "App"
