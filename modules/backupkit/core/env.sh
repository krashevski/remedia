#!/usr/bin/env bash
# modules/backupkit/core/env.sh

set -euo pipefail

# GLOBAL ROOT
export BACKUP_ROOT="${BACKUP_ROOT:-/mnt/backups/backupkit}"

# USER CONTEXT (источник истины)
BK_USER="${RUN_USER:-$(whoami)}"
export BK_USER 

# USER ROOT (единственная производная)
export USER_ROOT="$BACKUP_ROOT/user_data/$BK_USER"

# SUBSYSTEM PATHS
export SNAPSHOT_ROOT="$USER_ROOT/snapshots"
export STATE_DIR="$USER_ROOT/state"

# REGISTRY
export REGISTRY_DIR="$BACKUP_ROOT/registry"

# FIREFOX BACKUP CONFIG
export FIREFOX_DIR="${FIREFOX_DIR:-$BACKUP_ROOT/firefox}"
export FIREFOX_BACKUP_ROOT="$FIREFOX_DIR/$BK_USER"
export FIREFOX_BOOKMARKS_ROOT="$FIREFOX_BACKUP_ROOT/bookmarks"

# TMP
export TMP_DIR="${TMP_DIR:-/tmp/remedia/backupkit}"
export DIFF_TMP_ROOT="$TMP_DIR/diff"

# POLICY
export MAX_DIFF_DEPTH="${MAX_DIFF_DEPTH:-5}"
export MAX_DIFF_SIZE_MB="${MAX_DIFF_SIZE_MB:-5000}"
export MAX_FULL_AGE_SEC="${MAX_FULL_AGE_SEC:-86400}"

runtime_require BACKUP_ROOT
runtime_require BK_USER
runtime_require USER_ROOT

# ensure dirs
ensure_dir "$BACKUP_ROOT"
ensure_dir "$USER_ROOT"
ensure_dir "$REGISTRY_DIR"
ensure_dir "$FIREFOX_DIR"
ensure_dir "$FIREFOX_BACKUP_ROOT"
ensure_dir "$FIREFOX_BOOKMARKS_ROOT"
ensure_dir "$SNAPSHOT_ROOT"
ensure_dir "$STATE_DIR"
ensure_dir "$TMP_DIR"
ensure_dir "$DIFF_TMP_ROOT"

bk_snapshot_dir() {
    echo "$SNAPSHOT_ROOT/$1"
}

bk_snapshot_data_dir() {
    echo "$SNAPSHOT_ROOT/$1/snapshot"
}

bk_diff_dir() {
    echo "$SNAPSHOT_ROOT/$1/diff"
}

bk_state_file() {
    local name="$1"
    echo "$STATE_DIR/$name"
}
