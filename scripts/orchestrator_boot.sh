#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
PY="${HOME}/.venv/bin/python3"; [ -x "$PY" ] || PY="$(command -v python3)"
exec "$PY" ./orchestrator/main.py
