#!/usr/bin/env bash
# runtime_prelude.sh

set -euo pipefail

: "${HOME:=/tmp}"
: "${USER:=unknown}"

export PREFIX="${PREFIX:-/usr}"
export REMEDIA_LIB="${REMEDIA_LIB:-$PREFIX/lib/remedia}"

# 🔥 КЛЮЧЕВОЙ ФИКС
if [[ -z "${REMEDIA_ROOT:-}" ]]; then
    REMEDIA_ROOT="$REMEDIA_LIB"
fi

export REMEDIA_LIB REMEDIA_ROOT

export REMEDIA_VAR="${REMEDIA_VAR:-$HOME/.remedia}"
export CACHE_DIR="${CACHE_DIR:-$REMEDIA_VAR/cache}"
export LOG_DIR="${LOG_DIR:-$REMEDIA_VAR/logs}"

export FAST_STORAGE="${FAST_STORAGE:-/mnt/shotcut}"
export SLOW_STORAGE="${SLOW_STORAGE:-/mnt/storage}"
export BACKUP_STORAGE="${BACKUP_STORAGE:-/mnt/backups}"
