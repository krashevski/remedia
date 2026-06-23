#!/usr/bin/env bash
# core/state.sh - только сохранение/загрузка

declare -gA REMEDIA_STATE=()

state_save() {
    local key="$1"
    local value="$2"

    local tmp_file
    tmp_file="$(mktemp)"

    if [[ -f "$STATE_FILE" ]]; then
        grep -v "^$key=" "$STATE_FILE" > "$tmp_file" || true
    fi

    echo "$key=$value" >> "$tmp_file"
    mv "$tmp_file" "$STATE_FILE"

    # 🔥 ВАЖНО
    REMEDIA_STATE["$key"]="$value"
}

state_load() {
    [[ -f "$STATE_FILE" ]] || return 0

    while IFS='=' read -r key value; do
        REMEDIA_STATE["$key"]="$value"
    done < "$STATE_FILE"
}

state_get() {
    local key="$1"
    echo "${REMEDIA_STATE[$key]:-}"
}

state_init() {
    mkdir -p "$STATE_DIR"
    state_load
}
