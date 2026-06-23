#!/usr/bin/env bash
# modules/mediasystem/runtime/run_pipeline.sh for mediasystem

# =========================
# NORMALIZATION (ONLY HERE)
# =========================

PIPELINE_MODE="${PIPELINE_MODE:-safe}"

TOTAL=${#MODULES[@]}
CURRENT=0

# =========================
# EXECUTION LOOP
# =========================
TOTAL=${#MODULES[@]}
CURRENT=0

SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log_info "Pipeline start: mode=$PIPELINE_MODE modules=$TOTAL"

for MODULE in "${MODULES[@]}"; do
  CURRENT=$((CURRENT + 1))
  FULL="$MODULES_DIR/$MODULE"
  export MODULE_NAME="$(basename "$FULL")"

  if [[ ! -f "$FULL" ]]; then
    log_warn "missing module: $FULL"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi

  if ! policy_execute "$MODULE"; then
      SKIP_COUNT=$((SKIP_COUNT + 1))
      log_info "skipped by policy: $MODULE"
      continue
  fi

  if env -i \
      RUNTIME_DIR="$RUNTIME_DIR" \
      MODULES_DIR="$MODULES_DIR" \
      SHARED_DIR="$SHARED_DIR" \
      PACK_DIR="$PACK_DIR" \
      LOG_DIR="$LOG_DIR" \
      PIPELINE_MODE="$PIPELINE_MODE" \
      SAFE_MODE="$SAFE_MODE" \
      STATE_LIB="$STATE_LIB" \
      STATE_DIR="$STATE_DIR" \
      STATE_FILE="$STATE_FILE" \
      MEDIASYSTEM_VAR="$MEDIASYSTEM_VAR" \
      SHOTCUT_DIR="$SHOTCUT_DIR" \
      HOME="${HOME:-$REMEDIA_VAR/home}" \
      PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
      bash "$FULL" 2>&1 | tee -a "$LOG_DIR/pipeline.log"
  then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
      status=$?
      FAIL_COUNT=$((FAIL_COUNT + 1))
      log_error "failed: $MODULE ($status)"

       if [[ "$SAFE_MODE" == "1" ]]; then
          log_warn "safe mode → continue"
          continue
      else
          exit "$status"
      fi
  fi
done

echo
log_info "Pipeline finished"

# --- цвета (если не заданы в log.sh) ---
GREEN="${GREEN:-\033[0;32m}"
RED="${RED:-\033[0;31m}"
YELLOW="${YELLOW:-\033[0;33m}"
CYAN="${CYAN:-\033[0;36m}"
BOLD="${BOLD:-\033[1m}"
NC="${NC:-\033[0m}"

# защита от деления на 0
TOTAL_SAFE="${TOTAL:-0}"
if [[ "$TOTAL_SAFE" -eq 0 ]]; then
  PERCENT=0
else
  PERCENT=$(( SUCCESS_COUNT * 100 / TOTAL_SAFE ))
fi

echo -e "${BOLD}${CYAN}========== PIPELINE SUMMARY ==========${NC}"

printf " %-10s %b%s%b\n" "OK:"   "$GREEN"  "$SUCCESS_COUNT" "$NC"
printf " %-10s %b%s%b\n" "FAIL:" "$RED"    "$FAIL_COUNT"    "$NC"
printf " %-10s %b%s%b\n" "SKIP:" "$YELLOW" "$SKIP_COUNT"    "$NC"

echo

# процент тоже цветной (логика цвета)
if [[ "$PERCENT" -ge 90 ]]; then
  RATE_COLOR="$GREEN"
elif [[ "$PERCENT" -ge 60 ]]; then
  RATE_COLOR="$YELLOW"
else
  RATE_COLOR="$RED"
fi

printf " %-10s %b%s%%%b\n" "SUCCESS:" "$RATE_COLOR" "$PERCENT" "$NC"

echo -e "${BOLD}${CYAN}======================================${NC}"
