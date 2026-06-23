#!/usr/bin/env bash
# modules/mediapanel/entry.sh

# PATTERN: module bootstrap loader (systemd-inspired init layer)
# PATTERN: hierarchical filesystem namespace (REMEDIA_ROOT → module → runtime)
# PATTERN: declarative environment initialization (env-driven configuration)
# PATTERN: safe filesystem provisioning (idempotent mkdir -p bootstrap)
# PATTERN: layered state initialization (config → bootstrap → runtime state)

# ROLE:
# Initializes module runtime environment, filesystem structure,
# and loads core system dependencies in strict order.
# ROLE: module bootstrap only
# MUST NOT contain business logic
# MUST NOT contain execution decisions

# CORE DEPENDENCIES:
# project.sh MUST be loaded before export.sh

MODULE_NAME="mediapanel"
MODULE_DESC="mediapanel tools"

PREFIX="/usr/"
REMEDIA_LIB="$PREFIX/lib/remedia"
REMEDIA_CORE="$REMEDIA_LIB/core"
# source "$REMEDIA_CORE/log.sh"

: "${CACHE_DIR:?CACHE_DIR missing}"
: "${REMEDIA_LIB:?REMEDIA_LIB missing}"

# BOOTSTRAP DIRECTORIES
export REMEDIA_VAR="${REMEDIA_VAR:-$HOME/.remedia}"
export MEDIAPANEL_VAR="$REMEDIA_VAR/mediapanel"

# export LOG_DIR="$MEDIAPANEL_VAR/log"
# ensure_dir "$LOG_DIR"

# MEDIAPANEL BACKUPS
export MEDIAPANEL_BACKUPS="${MEDIAPANEL_BACKUPS:-${REMEDIA_BACKUPS:-/mnt/backups}/mediapanel}"

# LOGS SYSTEM
SYSTEM_LOG="${SYSTEM_LOG:-$REMEDIA_VAR/logs/system.log}"

# MEDIA CORE (глобально)
export RAW_DIR="$MEDIAPANEL_VAR/raw_cache"
export MEDIA_DB="$MEDIAPANEL_VAR/media_index.db"
export JOURNAL="$MEDIAPANEL_VAR/media_journal.log"

# определяем директорию текущего модуля
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# UI SYSTEM
SYSTEM_DEPS_PATH="${SYSTEM_DEPS_PATH:-$MODULE_DIR/core/system_deps.sh}"

# LOG
source "$MODULE_DIR/shared-lib/log.sh"
# SHARED-LIB
source "$MODULE_DIR/shared-lib/system_tools.sh"

# CORE MEDIAPANEL
source "$MODULE_DIR/core/system_deps.sh"
source "$MODULE_DIR/core/project.sh"
source "$MODULE_DIR/core/project_core.sh"
source "$MODULE_DIR/core/production.sh"
source "$MODULE_DIR/core/pipeline_state.sh"
source "$MODULE_DIR/core/export_render.sh"
source "$MODULE_DIR/core/export.sh"
source "$MODULE_DIR/core/api.sh"

# STATE
export STATE_DIR="$MEDIAPANEL_VAR"
source "$REMEDIA_CORE/state.sh"
export STATE_FILE="$STATE_DIR/state_panel.env"
# state_init

# RUNTIME DIRS
export TRASH_DIR="${TRASH_DIR:-$STATE_DIR/trash}"
# export CACHE_DIR="${CACHE_DIR:-$STATE_DIR/cache}"
# export TEMP_DIR="${TEMP_DIR:-$STATE_DIR/tmp}"

# FEATURES
source "$MODULE_DIR/modules/media_pool.sh"

# UI
source "$MODULE_DIR/ui/system.sh"
source "$MODULE_DIR/module.sh"

ensure_dir "$REMEDIA_VAR"
ensure_dir "$MEDIAPANEL_VAR"
ensure_dir "$MEDIAPANEL_BACKUPS"
ensure_dir "$RAW_DIR"
ensure_dir "$STATE_DIR"
ensure_dir "$TRASH_DIR"

touch "$SYSTEM_LOG"
touch "$MEDIA_DB" 
touch "$JOURNAL"
touch "$STATE_FILE"
