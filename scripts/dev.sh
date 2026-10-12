#!/usr/bin/env bash
# Runs the app and, only for as long as it runs, the optional developer AI server.
#
#   scripts/dev.sh                    # flutter run, with the server on this computer
#   scripts/dev.sh -d chrome          # any flutter run arguments are passed on
#   scripts/dev.sh --no-server -d ios # just flutter run, no server
#
# You do not need the server. The released app never uses it: the AI runs on
# the phone, or with the learner's own key. The server only helps in debug
# builds (and in a browser) when neither is set up yet. It stops when the app
# stops. Without a key in ai-server/.env it falls back to local Ollama.
set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-flutter}"
PORT="${PORT:-8000}"
SERVER=1
if [[ "${1:-}" == "--no-server" ]]; then SERVER=0; shift; fi

PID=""
cleanup() { [[ -n "$PID" ]] && kill "$PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

if [[ "$SERVER" == 1 ]]; then
  if curl -fs "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    echo "AI server already running on port ${PORT}; leaving it alone."
  else
    PY=python3
    [[ -x ai-server/.venv/bin/python ]] && PY="$PWD/ai-server/.venv/bin/python"
    if ! "$PY" -c "import uvicorn, fastapi" 2>/dev/null; then
      echo "AI server skipped: run  pip install -r ai-server/requirements.txt  to enable it."
    else
      (cd ai-server && exec "$PY" -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT" \
        >/tmp/sprichst-ai-server.log 2>&1) &
      PID=$!
      for _ in $(seq 1 20); do
        curl -fs "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1 && break
        kill -0 "$PID" 2>/dev/null || { echo "AI server did not start; see /tmp/sprichst-ai-server.log"; PID=""; break; }
        sleep 0.5
      done
      [[ -n "$PID" ]] && echo "AI server started on http://127.0.0.1:${PORT} (log: /tmp/sprichst-ai-server.log)"
    fi
  fi
fi

"$FLUTTER" run "$@"
