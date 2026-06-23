#!/usr/bin/env bash
# core/cache.sh - cache layer

CACHE_TTL=5

CACHE_GPU=""
CACHE_NVENC=""
CACHE_GPU_TS=0
CACHE_NVENC_TS=0

cache_now() {
    runtime_require CACHE_DIR
    date +%s
}

get_gpu_cached() {
    runtime_require CACHE_DIR
    local now
    now="$(cache_now)"

    if (( now - CACHE_GPU_TS < CACHE_TTL )); then
        echo "$CACHE_GPU"
        return
    fi

    if lspci | grep -qi nvidia; then
        CACHE_GPU="NVIDIA"
    else
        CACHE_GPU="CPU"
    fi

    CACHE_GPU_TS="$now"
    echo "$CACHE_GPU"
}

get_nvenc_cached() {
    runtime_require CACHE_DIR
    local now
    now="$(cache_now)"

    if (( now - CACHE_NVENC_TS < CACHE_TTL )); then
        echo "$CACHE_NVENC"
        return
    fi

    # 1. Проверка GPU
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        CACHE_NVENC="NO_GPU"
    # 2. Проверка ffmpeg encoder
    elif ffmpeg -encoders 2>/dev/null | grep -qE 'h264_nvenc|hevc_nvenc'; then
        CACHE_NVENC="YES"
    else
        CACHE_NVENC="NO_FFMPEG"
    fi

    CACHE_NVENC_TS="$now"
    echo "$CACHE_NVENC"
}

get_dir_size_cached() {
    local dir="${1:-}"

    [[ -z "$dir" ]] && { echo "N/A"; return 0; }

    : "${CACHE_DIR:?CACHE_DIR missing}"

    mkdir -p "$CACHE_DIR" || return 0

    local hash file size

    hash="$(printf "%s" "$dir" | md5sum | awk '{print $1}')"
    file="$CACHE_DIR/system_cache_$hash"

    # cache hit
    if [[ -f "$file" ]]; then
        head -n1 "$file"
        return 0
    fi

    # safe compute (НЕ ломаем runtime)
    size="$(du -sh "$dir" 2>/dev/null | awk '{print $1}')"

    [[ -z "$size" ]] && size="ERR"

    printf "%s\n" "$size" > "${file}.tmp"
    sync "${file}.tmp" 2>/dev/null || true
    mv "${file}.tmp" "$file"

    # fallback safety
    [[ -z "$size" ]] && size="ERR"

    # atomic write (ВАЖНО!)
    echo "[DEBUG] cache file = $file"
    echo "[DEBUG] tmp file = ${file}.tmp"
    printf "%s\n" "$size" > "${file}.tmp" && mv "${file}.tmp" "$file"
    echo "[DEBUG] actual file path:"
    ls -l "$CACHE_DIR" | grep system_cache || true
    echo "$size"
}

cache_invalidate_gpu() {
    CACHE_GPU_TS=0
}
