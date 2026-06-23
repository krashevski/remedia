#!/usr/bin/env bash
# 45_gpu_autotest.sh

set -euo pipefail

: "${SHARED_DIR:?}"
: "${MEDIASYSTEM_VAR:?}"

# init module name
export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

# logging
source "$SHARED_DIR/log.sh"
log_init_once

# -------------------------
# LOAD ENV FIRST
# -------------------------
ENV_FILE="$MEDIASYSTEM_VAR/best_gpu_preset.env"

if [[ ! -f "$ENV_FILE" ]] || ! grep -q "BEST_GPU_PRESET=" "$ENV_FILE"; then
    log_error "Invalid ENV file: $ENV_FILE"
    exit 1
fi

source "$ENV_FILE"

if [[ -z "${BEST_GPU_PRESET:-}" ]]; then
    log_error "BEST_GPU_PRESET is empty"
    exit 1
fi

TEST_INPUT="$MEDIASYSTEM_VAR/remedia_test_input_$$.mp4"
TEST_OUTPUT="$MEDIASYSTEM_VAR/remedia_test_output_$$.mp4"

declare -A NVENC_MAP=(
  [nvenc_h264]="h264_nvenc"
  [nvenc_hevc]="hevc_nvenc"
  [nvenc_av1]="av1_nvenc"
  [cpu]="libx264"
)

ffmpeg -y -f lavfi -i testsrc=duration=3:size=1280x720:rate=30 \
    -c:v libx264 "$TEST_INPUT" >/dev/null 2>&1
    
if [[ -z "${NVENC_MAP[$BEST_GPU_PRESET]+x}" ]]; then
    log_warn "Unknown preset: $BEST_GPU_PRESET → fallback cpu"
    BEST_GPU_PRESET="cpu"
fi

CODEC="${NVENC_MAP[$BEST_GPU_PRESET]:-${NVENC_MAP[cpu]}}"

if [[ -z "$CODEC" ]]; then
    log_error "Unknown preset: $BEST_GPU_PRESET"
    exit 1
fi

ffmpeg -y -i "$TEST_INPUT" \
    -c:v "$CODEC" \
    -t 3 \
    "$TEST_OUTPUT" >/dev/null 2>&1

STATUS=$?

if [[ $STATUS -ne 0 || ! -f "$TEST_OUTPUT" ]]; then
    log_warn "GPU preset failed → fallback to CPU"

    BEST_GPU_PRESET="libx264"

    tmp_file="$ENV_FILE.tmp"
    echo "BEST_GPU_PRESET=$BEST_GPU_PRESET" > "$tmp_file"
    mv "$tmp_file" "$ENV_FILE"

    log_info "Fallback preset set: $BEST_GPU_PRESET"
else
    log_info "GPU preset test OK: $BEST_GPU_PRESET"
fi

log_info "=== Completed $MODULE_NAME ==="
