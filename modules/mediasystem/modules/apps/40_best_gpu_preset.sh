#!/bin/bash
# 40_best_gpu_preset.sh

set -euo pipefail 

: "${SHARED_DIR:?}"

# init module name
export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

# logging
source "$SHARED_DIR/log.sh"
log_init_once

MIN_TIME=999999
BEST_PRESET=""

log_info "=== Starting $MODULE_NAME ==="

echo "Selecting best GPU preset for project render"

REPORT_FILE="$MEDIASYSTEM_VAR/gpu_preset_benchmark.txt"

# --- Проверка отчёта ---
if [ ! -f "$REPORT_FILE" ]; then
    log_warn "Benchmark report not found, falling back to CPU"
    export BEST_GPU_PRESET=""
    exit 0
fi

# --- Анализ отчёта: ищем успешные и минимальное время ---
while read -r line; do
    preset=$(echo "$line" | cut -d: -f1)
    time=$(echo "$line" | grep -o 'Time=[0-9]*' | cut -d= -f2)

    [[ "$time" =~ ^[0-9]+$ ]] || continue
    (( time >= 1 && time < MIN_TIME )) || continue

    MIN_TIME=$time
    BEST_PRESET=$preset
done < <(grep "SUCCESS" "$REPORT_FILE")

BEST_GPU_PRESET="${BEST_PRESET:-cpu}"

ENV_FILE="$MEDIASYSTEM_VAR/best_gpu_preset.env"

echo "BEST_GPU_PRESET=$BEST_GPU_PRESET" > "$ENV_FILE"

log_info "Selected GPU preset: $BEST_GPU_PRESET (time=$MIN_TIME)"

# --- Настройка Shotcut под лучший кодек ---
SHOTCUT_CONFIG_DIR="$HOME/.var/app/org.shotcut.Shotcut/config/shotcut"
mkdir -p "$SHOTCUT_CONFIG_DIR"
CONFIG_FILE="$SHOTCUT_CONFIG_DIR/user.presets.xml"

if [ -n "$BEST_GPU_PRESET" ]; then
    echo "Writing best GPU preset to Shotcut configuration"

    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<presets>'
        echo "  <encoder>$BEST_GPU_PRESET</encoder>"
        echo '</presets>'
    } > "$CONFIG_FILE"

    echo "Shotcut configured to use $BEST_GPU_PRESET"
else
    echo "No GPU preset applied (CPU fallback)"
fi

# --- Лог как артефакт профиля ---
{
    echo "=== $(date) ==="
    echo "Best GPU preset selected for project render:"
    echo "$BEST_GPU_PRESET"
    echo
} >> "$MEDIASYSTEM_VAR/best_gpu_preset.txt"

if [[ -z "$BEST_GPU_PRESET" ]]; then
    BEST_GPU_PRESET="cpu"
fi

export BEST_GPU_PRESET

echo "Automatic best GPU preset selection complete"

log_info "=== Completed $MODULE_NAME ==="
