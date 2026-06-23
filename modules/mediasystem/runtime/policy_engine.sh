#!/usr/bin/env bash
# modules/mediasystem/runtime/policy_engine.sh

# “Policy-driven execution engine (inspired by systemd)”
# PATTERN: systemd (unit conditions + execution policy)
# PATTERN: feature flags / policy gating (runtime decision layer)
# PATTERN: declarative pipeline modes (safe / standard / full)

# IDEA:
# Centralized decision engine that controls whether modules are executed
# based on environment, hardware, and external policy files.

# WHY:
# - отделить "что запускать" от "как запускать"
# - добавить управляемость pipeline без изменения модулей
# - обеспечить безопасные режимы выполнения (safe mode)

# SOURCE:
# - systemd: Condition*, unit control, enable/disable services
# - modern CI/CD: feature flags, skip rules
# - GPU-aware installers (CUDA / drivers): hardware detection gating

# POLICY RETURN CODES (protocol)
# 0 = allow execution
# 1 = skip execution

policy_init() {
    PIPELINE_MODE="${PIPELINE_MODE:-safe}"
    SAFE_MODE="${SAFE_MODE:-0}"
}

policy_allow() {
    local module="$1"

    echo "[DEBUG policy_allow] $module" >&2
    # disabled list
    local policy_dir="${POLICY_DIR:-$MEDIASYSTEM_VAR}"
    if [[ -f "$policy_dir/disabled.list" ]]; then
        grep -qx "$module" "$policy_dir/disabled.list" && {
            return 1
        }
    fi

    # GPU rules
    if [[ "$module" == *cuda* || "$module" == *nvidia* ]]; then
        if ! lspci 2>/dev/null | grep -qi nvidia; then
            return 1
        fi
    fi

    return 0
}

policy_plan() {
    local mode="$PIPELINE_MODE"

    case "$mode" in
        safe)
            MODULES=("${MODULES_SAFE[@]}")
            SAFE_MODE=1
            ;;
        standard)
            MODULES=("${MODULES_STANDARD[@]}")
            SAFE_MODE=0
            ;;
        full)
            MODULES=("${MODULES_FULL[@]}")
            SAFE_MODE=0
            ;;
        *)
            echo "[WARN] invalid PIPELINE_MODE=$mode → safe"
            MODULES=("${MODULES_SAFE[@]}")
            SAFE_MODE=1
            ;;
    esac

    export MODULES SAFE_MODE
}

policy_execute() {
    local module="$1"

    if policy_allow "$module"; then
        log_info "[POLICY] run $module"
        return 0   # allow
    else
        log_info "[POLICY] skip $module"
        return 1   # skip
    fi
}

