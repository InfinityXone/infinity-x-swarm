#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export PORT="${PORT:-8080}"
echo "▶️  Starting uvicorn on http://127.0.0.1:$PORT"
uvicorn main:app --app-dir ./app --host 0.0.0.0 --port "$PORT" --log-level info
