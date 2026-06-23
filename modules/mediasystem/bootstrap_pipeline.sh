#!/usr/bin/env bash
# bootstrap_pipeline.sh

# REMEDIA SAFE GUARD (v2-lite)

: "${USER:=root}"
if [[ -z "${HOME:-}" ]]; then
    HOME="$(getent passwd "$USER" 2>/dev/null | cut -d: -f6)"
fi
: "${HOME:=/tmp/remedia/$USER}"
: "${REMEDIA_TRACE:=0}"
export USER HOME

PREFIX="/usr/"
REMEDIA_LIB="$PREFIX/lib/remedia"
REMEDIA_CORE="$REMEDIA_LIB/core"
source "$REMEDIA_CORE/env.sh"
source "$REMEDIA_CORE/kernel.sh"
source "$REMEDIA_CORE/state.sh"
export STATE_LIB="$REMEDIA_CORE/state.sh"

# critical dirs (always safe)
export REMEDIA_VAR="${REMEDIA_VAR:-$HOME/.remedia}"
mkdir -p "$REMEDIA_VAR"
export MEDIASYSTEM_VAR="$REMEDIA_VAR/mediasystem"
mkdir -p "$MEDIASYSTEM_VAR"

# 3. MODULE ROOT (один раз и правильно)
export MODULE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MODULES_DIR="$MODULE_ROOT/modules"
export PACK_DIR="$MODULE_ROOT/packages"
export SHARED_DIR="$MODULE_ROOT/shared-lib"
export CONFIG_DIR="$MODULE_ROOT/config"

# PIPELINE RUNTIME
export RUNTIME_DIR="${RUNTIME_DIR:-$MODULE_ROOT/runtime}"

# 4. SHARED LIBS
source "$SHARED_DIR/ui.sh"

# LOG
export LOG_DIR="$MEDIASYSTEM_VAR/log"
mkdir -p "$LOG_DIR"
export LOG_FILE="$LOG_DIR/pipeline.log"
MODULE_NAME="pipeline"
source "$SHARED_DIR/log.sh"
log_init

# 5. SHOTCUT CONFIG (после HOME гарантирован)
export SHOTCUT_CONFIG_DIR="$HOME/.var/app/org.shotcut.Shotcut/config/shotcut"
mkdir -p "$SHOTCUT_CONFIG_DIR"
export SHOTCUT_CONFIG_FILE="$SHOTCUT_CONFIG_DIR/user.presets.xml"

# 6. STATE (единый источник)
export STATE_DIR="$MEDIASYSTEM_VAR"
mkdir -p "$STATE_DIR"
export STATE_FILE="$STATE_DIR/state_system.env"
touch "$STATE_FILE"
# state_init

# LOAD CONFIG (NO LOGIC)
source "$CONFIG_DIR/config.sh"
# LOAD MANIFEST
source "$CONFIG_DIR/pipeline.manifest.sh"
# LOAD POLICY
# policy_engine.sh
# LOAD TRACKER
# source "$RUNTIME_DIR/tracker.sh"
source "$RUNTIME_DIR/policy_engine.sh"
policy_init
policy_plan

# LOAD RUN
source "$RUNTIME_DIR/run_pipeline.sh"
