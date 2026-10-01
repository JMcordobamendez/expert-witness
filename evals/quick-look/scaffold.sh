#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir board && cp "$here/fixture/report.md" "$here/fixture/sales-2025.csv" board/
