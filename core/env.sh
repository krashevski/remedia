#!/usr/bin/env bash
# core/env.sh — SAFE ENV CONTRACT

set -euo pipefail

# -------------------------
# USER / HOME CONTRACT
# -------------------------
: "${USER:=root}"

if [[ -z "${HOME:-}" ]]; then
    HOME="$(getent passwd "$USER" 2>/dev/null | cut -d: -f6)"
fi

: "${HOME:=/tmp/remedia/$USER}"

export USER HOME

# -------------------------
# SAFE DIR BASES
# -------------------------
export REMEDIA_VAR="${REMEDIA_VAR:-$HOME/.remedia}"
export REMEDIA_LOG="${REMEDIA_LOG:-/var/log/remedia}"
export REMEDIA_BACKUPS="${REMEDIA_BACKUPS:-/mnt/backups}"

# guarantee dirs (NO DEPENDENCIES YET)
mkdir -p "$REMEDIA_VAR" "$REMEDIA_LOG"
