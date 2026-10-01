#!/usr/bin/env bash
# Start script used by the service manager.
cd "$(dirname "$0")"
exec python3 -m app.main
