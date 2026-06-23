#!/bin/bash
# 30_gpu_preset_benchmark.sh

set -euo pipefail 

: "${SHARED_DIR:?}"

# init module name
export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

# logging
source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

source "${STATE_LIB:?}"
source "$SHARED_DIR/shotcut_env.sh"

state_init
PRESETS_STR="$(state_get SELECTED_PRESETS)"
IFS=',' read -r -a SELECTED_PRESETS <<< "$PRESETS_STR"

shotcut_write_presets "${SELECTED_PRESETS[@]}"
shotcut_sync_log "${SELECTED_PRESETS[@]}"

# SAFE MODE
if [ "${SAFE_MODE:-0}" -eq 1 ]; then
    log_info "[SAFE MODE] Skipping benchmark"
    exit 100
fi

ENABLE_BENCH=y

if [ "${PIPELINE_MODE:-}" = "full" ] && [ "${ENABLE_BENCH:-n}" != "y" ]; then
    log_info "[FULL MODE] Benchmark disabled"
    exit 0
fi

if [ "${#SELECTED_PRESETS[@]}" -eq 0 ]; then
    echo "No GPU presets selected, skipping benchmark"
    exit 0
fi

# --- Проверка ffmpeg ---
if ! command -v ffmpeg &>/dev/null; then
    echo "ffmpeg not found, skipping benchmark"
    exit 0
fi

# --- Тестовый файл (короткий, для быстрого бенчмарка) ---
TEST_VIDEO="$MEDIASYSTEM_VAR/reprom_test_video.mp4"
if [ ! -f "$TEST_VIDEO" ]; then
    echo "Creating test video"
    ffmpeg -f lavfi -i testsrc=size=1280x720:rate=30 -t 5 -pix_fmt yuv420p "$TEST_VIDEO" -y
fi

# --- Лог и report ---
REPORT_FILE="$MEDIASYSTEM_VAR/gpu_preset_benchmark.txt"

echo "=== $(date) ===" >> "$REPORT_FILE"
echo "GPU Preset Benchmark Report" >> "$REPORT_FILE"
echo "Input test video: $TEST_VIDEO" >> "$REPORT_FILE"
echo >> "$REPORT_FILE"

declare -A NVENC_MAP=(
    [nvenc_h264]="h264_nvenc"
    [nvenc_hevc]="hevc_nvenc"
    [nvenc_av1]="av1_nvenc"
)

# --- GPU runtime check (correct version) ---
GPU_AVAILABLE=0

if [[ -d /dev/nvidia0 ]] || [[ -c /dev/nvidia0 ]]; then
    GPU_AVAILABLE=1
fi

if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -E "h264_nvenc|hevc_nvenc|av1_nvenc"; then
    echo "NVENC not available in ffmpeg, skipping benchmark"
    exit 0
fi

if [[ "$GPU_AVAILABLE" -ne 1 ]]; then
    echo "NVENC GPU not available → fallback to CPU"
    USE_CPU_FALLBACK=1
else
    USE_CPU_FALLBACK=0
fi

# --- Функция тестирования одного пресета ---
benchmark_preset() {
    local preset=$1
    local output="$MEDIASYSTEM_VAR/remedia_test_${preset}.mp4"
    local codec="${NVENC_MAP[$preset]:-}"

    if [[ -z "$codec" ]]; then
        echo "[WARN] Unknown preset: $preset"
        echo "$preset: UNKNOWN" >> "$REPORT_FILE"
        exit 0
    fi

    echo "[BENCH] Testing preset: $preset -> $codec"

    local input="${TEST_VIDEO:-$MEDIASYSTEM_VAR/remedia_test_input.mp4}"

    if [[ ! -f "$input" ]]; then
        ffmpeg -y -f lavfi -i testsrc=duration=3:size=1280x720:rate=30 \
            -c:v libx264 "$input" >/dev/null 2>&1
    fi

    local start end elapsed

    start=$(date +%s%N)

    if ffmpeg -y -i "$input" -c:v "$codec" -preset p4 -tune hq -b:v 5M -t 3 "$output" \
        2>>"$MEDIASYSTEM_VAR/ffmpeg_nvenc_error.log"; then

        end=$(date +%s%N)
        elapsed=$(awk "BEGIN {printf \"%.3f\", ($end - $start)/1000000000}")

        echo "[OK] $preset in ${elapsed}s"
        echo "$preset: SUCCESS, codec=$codec, Time=${elapsed}s" >> "$REPORT_FILE"
    else
        echo "[FAIL] $preset"
        echo "$preset: FAILED, codec=$codec" >> "$REPORT_FILE"
        # ❗ НЕ exit
    fi

    rm -f "$output"
    exit 0
}

# --- Запуск всех пресетов ---

for preset in "${SELECTED_PRESETS[@]}"; do
    benchmark_preset "$preset"
done

echo "GPU preset benchmark complete"
echo "Report saved to $REPORT_FILE"

log_info "=== Completed $MODULE_NAME ==="
