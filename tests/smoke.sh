#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
export NURVNET_NO_OPEN=1

"$ROOT/nurvnet" prepare
command -v docker >/dev/null 2>&1 || { printf 'Docker is required for the live smoke test.\n' >&2; exit 1; }

set -a
# shellcheck disable=SC1091
. "$ROOT/.env"
# shellcheck disable=SC1091
. "$ROOT/.runtime/secrets.env"
set +a

cleanup() {
  (cd "$ROOT" && docker compose down) || true
}
trap cleanup EXIT HUP INT TERM

"$ROOT/nurvnet" start
curl -fsS "http://localhost:${CLIPROXY_PORT:-8317}/healthz" | grep -q '"status":"ok"'
curl -fsS -H "Authorization: Bearer $CLIPROXY_API_KEY" \
  "http://localhost:${CLIPROXY_PORT:-8317}/v1/models" | grep -q '"data"'
curl -fsS "http://localhost:${CLIPROXY_PORT:-8317}/management.html" | grep -qi '<html'
curl -fsS "http://localhost:${WEBUI_PORT:-3000}/health" | grep -q '"status":true'
printf 'Live smoke test passed.\n'
