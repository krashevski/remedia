

declare -a REMEDIA_HOOK_PRE_RUN=()
declare -a REMEDIA_HOOK_POST_RUN=()
declare -a REMEDIA_HOOK_ERROR=()

remedia_hook_pre() {
    REMEDIA_HOOK_PRE_RUN+=("$1")
}

remedia_hook_post() {
    REMEDIA_HOOK_POST_RUN+=("$1")
}

remedia_hook_error() {
    REMEDIA_HOOK_ERROR+=("$1")
}

_run_hooks() {
    local -n hooks=$1
    shift

    for fn in "${hooks[@]}"; do
        if command -v "$fn" >/dev/null 2>&1; then
            "$fn" "$@"
        fi
    done
}

