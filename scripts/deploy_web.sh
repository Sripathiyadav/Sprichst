#!/usr/bin/env bash
# Builds the web app and deploys it to Firebase Hosting (HTTPS, with the
# security headers from firebase/firebase.json).
#
#   scripts/deploy_web.sh qa 1d     # a private preview link that expires (default)
#   scripts/deploy_web.sh live      # the real site
#
# The Firebase CLI refuses a public folder outside the folder that holds the
# config, so a copy of the config with the build path rewritten is used for the
# deploy and removed afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

target="${1:-qa}"
expires="${2:-1d}"
project="${FIREBASE_PROJECT:-sprichst-74bed}"

flutter build web --release

tmp="$(mktemp .firebase-deploy.XXXXXX.json)"
trap 'rm -f "$tmp"' EXIT
python3 - "$tmp" <<'PY'
import json, sys
config = json.load(open("firebase/firebase.json"))
config["hosting"]["public"] = "build/web"
for key in ("firestore", "storage"):
    config.pop(key, None)
json.dump(config, open(sys.argv[1], "w"))
PY

if [ "$target" = "live" ]; then
  firebase --config "$tmp" deploy --only hosting --project "$project"
else
  firebase --config "$tmp" hosting:channel:deploy "$target" \
    --expires "$expires" --project "$project"
fi
