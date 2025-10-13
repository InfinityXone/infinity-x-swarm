#!/usr/bin/env bash
set -euo pipefail
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
echo "🔎 GET /healthz"
curl -sSf "http://$HOST:$PORT/healthz" | jq . || curl -s "http://$HOST:$PORT/healthz"
echo
echo "🔎 GET /ready"
curl -sSf "http://$HOST:$PORT/ready" | jq . || curl -s "http://$HOST:$PORT/ready"
echo
