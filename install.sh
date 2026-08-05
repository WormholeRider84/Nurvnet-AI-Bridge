#!/bin/sh
set -eu

REPOSITORY=WormholeRider84/Nurvnet-AI-Bridge
ASSET=Nurvnet-AI-Bridge.tar.gz

die() {
  printf 'Nurvnet-AI-Bridge: %s\n' "$*" >&2
  exit 1
}

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    die "curl or wget is required"
  fi
}

script_dir=
case $0 in
  */*) script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || true ;;
esac

if [ -n "$script_dir" ] && [ -f "$script_dir/compose.yaml" ]; then
  install_dir=$script_dir
else
  install_dir=${NURVNET_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nurvnet-ai-bridge}
  archive_dir=$(mktemp -d "${TMPDIR:-/tmp}/nurvnet-ai-bridge.XXXXXX")
  archive=$archive_dir/$ASSET
  checksum=$archive.sha256
  release_url=https://github.com/$REPOSITORY/releases/latest/download

  trap 'test -n "${archive_dir:-}" && test -d "$archive_dir" && rm -rf -- "$archive_dir"' EXIT HUP INT TERM
  printf 'Downloading Nurvnet-AI-Bridge...\n'
  download "$release_url/$ASSET" "$archive" || die "release download failed; clone the repository and run ./install.sh"
  download "$release_url/$ASSET.sha256" "$checksum"

  expected=$(awk 'NR == 1 { print $1 }' "$checksum")
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$archive" | awk '{ print $1 }')
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$archive" | awk '{ print $1 }')
  else
    die "sha256sum or shasum is required to verify the release"
  fi
  [ "$actual" = "$expected" ] || die "release checksum verification failed"

  mkdir -p "$install_dir"
  tar -xzf "$archive" -C "$install_dir" --strip-components=1
fi

chmod +x "$install_dir/nurvnet" "$install_dir/scripts/"*.sh
exec "$install_dir/nurvnet" install
