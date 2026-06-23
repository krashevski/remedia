#!/usr/bin/env bash
# core/prelude.sh 

set -euo pipefail

: "${USER:=unknown}"
: "${HOME:=/tmp}"

export PREFIX="${PREFIX:-/usr}"
export REMEDIA_LIB="${REMEDIA_LIB:-$PREFIX/lib/remedia}"

export REMEDIA_VAR="${REMEDIA_VAR:-$HOME/.remedia}"

export CACHE_DIR="${CACHE_DIR:-$HOME/.remedia/cache}"
export LOG_DIR="${LOG_DIR:-$HOME/.remedia/logs}"

export FAST_STORAGE="${FAST_STORAGE:-/mnt/shotcut}"
export SLOW_STORAGE="${SLOW_STORAGE:-/mnt/storage}"
export BACKUP_STORAGE="${BACKUP_STORAGE:-/mnt/backups}"

export STATE_DIR="${STATE_DIR:-$HOME/.remedia/state}"
export STATE_FILE="${STATE_FILE:-$STATE_DIR/state.db}"
