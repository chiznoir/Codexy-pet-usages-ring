#!/usr/bin/env sh
set -eu
SCRIPT_PATH=$(printf '%s\n' "$0" | tr '\\' '/')
case "$SCRIPT_PATH" in
  */*) SCRIPT_DIR=${SCRIPT_PATH%/*} ;;
  *) SCRIPT_DIR=. ;;
esac
DIR=$(CDPATH= cd "$SCRIPT_DIR" && pwd)
ROOT=$(CDPATH= cd "$DIR/../.." && pwd)
. "$DIR/resolve-root.sh"
ROOT=$(resolve_codex_pet_root "$ROOT" "Settings.ps1")
sh "$DIR/run-powershell.sh" "$ROOT/bin/powershell/Settings.ps1" "$@"
