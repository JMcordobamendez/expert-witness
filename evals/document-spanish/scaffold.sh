#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir informe && cp "$here/fixture/informe.md" "$here/fixture/costes-2025.csv" informe/
