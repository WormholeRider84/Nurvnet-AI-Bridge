#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
DIST=$ROOT/dist
PREFIX=Nurvnet-AI-Bridge/

command -v git >/dev/null 2>&1 || { printf 'git is required\n' >&2; exit 1; }
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  printf 'Run packaging from a Git repository.\n' >&2
  exit 1
}

mkdir -p "$DIST"
git -C "$ROOT" archive --format=tar.gz --prefix="$PREFIX" -o "$DIST/Nurvnet-AI-Bridge.tar.gz" HEAD
git -C "$ROOT" archive --format=zip --prefix="$PREFIX" -o "$DIST/Nurvnet-AI-Bridge.zip" HEAD

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$DIST" && sha256sum Nurvnet-AI-Bridge.tar.gz >Nurvnet-AI-Bridge.tar.gz.sha256)
  (cd "$DIST" && sha256sum Nurvnet-AI-Bridge.zip >Nurvnet-AI-Bridge.zip.sha256)
else
  (cd "$DIST" && shasum -a 256 Nurvnet-AI-Bridge.tar.gz >Nurvnet-AI-Bridge.tar.gz.sha256)
  (cd "$DIST" && shasum -a 256 Nurvnet-AI-Bridge.zip >Nurvnet-AI-Bridge.zip.sha256)
fi

printf 'Release files written to %s\n' "$DIST"
