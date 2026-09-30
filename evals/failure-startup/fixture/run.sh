#!/usr/bin/env bash
# Start script used by the service manager.
here="$(cd "$(dirname "$0")" && pwd)"
cd /
exec python3 "$here/app/server.py"
