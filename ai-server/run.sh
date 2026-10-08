#!/usr/bin/env bash
# Starts the Sprichst AI server so that phones on your Wi-Fi can reach it.
#
#   ./run.sh              listens on your network (0.0.0.0), port 8000
#   ./run.sh --local      listens on this computer only (simulator, desktop, web)
#
# Then, in the app: Account → AI & voice → AI server, enter the address printed
# below, and tap "Save and test". The server has no login, so only do this on a
# network you trust.
set -euo pipefail
cd "$(dirname "$0")"

HOST="0.0.0.0"
if [[ "${1:-}" == "--local" ]]; then HOST="127.0.0.1"; fi

if [[ -d .venv ]]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

if [[ "$HOST" == "0.0.0.0" ]]; then
  IP="$( (ipconfig getifaddr en0 || ipconfig getifaddr en1 || hostname -I | awk '{print $1}') 2>/dev/null | head -n1 || true)"
  if [[ -n "${IP}" ]]; then
    echo "On a phone, use this server address:  http://${IP}:${PORT:-8000}"
  fi
fi

exec uvicorn app.main:app --reload --host "$HOST" --port "${PORT:-8000}"
