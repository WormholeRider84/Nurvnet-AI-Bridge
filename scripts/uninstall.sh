#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  (cd "$ROOT" && docker compose down)
fi

if [ "${1:-}" = --purge ]; then
  [ -f "$ROOT/compose.yaml" ] || { printf 'Refusing to purge an unrecognized directory.\n' >&2; exit 1; }
  [ "$(basename -- "$ROOT")" = nurvnet-ai-bridge ] || {
    printf 'Refusing to purge %s automatically; remove it manually if intended.\n' "$ROOT" >&2
    exit 1
  }
  printf 'This permanently deletes all chats, credentials, configuration, and logs. Type PURGE: '
  read -r answer
  [ "$answer" = PURGE ] || { printf 'Cancelled.\n'; exit 0; }
  parent=$(dirname -- "$ROOT")
  target=$(basename -- "$ROOT")
  cd "$parent"
  rm -rf -- "$target"
  printf 'Nurvnet-AI-Bridge and its local data were permanently removed.\n'
else
  printf 'Containers removed; persistent data remains in %s.\n' "$ROOT"
  printf 'Run %s --purge to permanently delete it.\n' "$0"
fi
