#!/usr/bin/env bash
# very small temporal workflow engine

set -euo pipefail

MODULE_NAME="demo"
MODULE_DESC="demo tools"

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CINEMA_ROOT="$MODULE_DIR/modules/cinema"

export REMEDIA_VAR="${REMEDIA_VAR:-$HOME/.remedia}"
mkdir -p "$REMEDIA_VAR"
export DEMO_VAR="$REMEDIA_VAR/demo"
mkdir -p "$DEMO_VAR"
export STATE_DIR="$DEMO_VAR/state"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/replay.log"

STEPS=(
  "$CINEMA_ROOT/steps/01_create_dir.sh"
  "$CINEMA_ROOT/steps/02_write_file.sh"
  "$CINEMA_ROOT/steps/03_fail_step.sh"
)

# CINEMA MODULE
source "$CINEMA_ROOT/scrub.sh"
source "$CINEMA_ROOT/replay.sh"
source "$CINEMA_ROOT/run_pipeline.sh"
source "$CINEMA_ROOT/module.sh"

# CLI USE
source "$MODULE_DIR/module.sh"


