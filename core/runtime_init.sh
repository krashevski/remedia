#!/usr/bin/env bash
# core/runtime_init.sh

RUNTIME_STATE="RAW"

runtime_mark_initialized() {
    RUNTIME_STATE="INIT"
    log_debug "runtime state = INIT"
}

runtime_mark_ready() {
    RUNTIME_STATE="READY"
    log_info "runtime state = READY"
}

runtime_assert_initialized() {
    [[ "$RUNTIME_STATE" == "INIT" ]] || {
        echo "[FATAL] runtime not initialized"
        exit 1
    }
}

runtime_assert_ready() {
    [[ "$RUNTIME_STATE" == "READY" ]] || {
        echo "[FATAL] runtime not ready"
        exit 1
    }
}

runtime_init() {
    init_user_context   # ПЕРВОЕ
    log_init            # ВТОРОЕ (использует USER)
    load_config
    declare -F storage_init >/dev/null && storage_init
    runtime_mark_initialized
}

runtime_boot() {
    runtime_assert_initialized

    # BOOT wiring
    source "$REMEDIA_LIB/core/router.sh"
    source "$REMEDIA_LIB/core/registry.sh"
    source "$REMEDIA_LIB/core/security.sh"
    source "$REMEDIA_LIB/core/cache.sh"
 
    source "$REMEDIA_LIB/core/utils/fs.sh"
       
    # ENGINE
    source "$REMEDIA_LIB/core/runtime_runtime.sh"
    source "$REMEDIA_LIB/core/system_bootstrap.sh"
    source "$REMEDIA_LIB/core/runtime.sh"

    log_info "system boot completed"
}

# 1. SAFE BASE (НИКАКОГО CRASH)
: "${REMEDIA_LIB:=/usr/lib/remedia}"
export REMEDIA_LIB

# LOAD PHASE (ВАЖНО)
source "$REMEDIA_LIB/core/guard.sh"
source "$REMEDIA_LIB/core/kernel.sh"
set -euo pipefail
source "$REMEDIA_LIB/core/prelude.sh"
source "$REMEDIA_LIB/core/env.sh"

source "$REMEDIA_LIB/core/runtime_prelude.sh"
source "$REMEDIA_LIB/core/runtime_guard.sh"
guard_runtime

source "$REMEDIA_LIB/core/utils/colors.sh"
source "$REMEDIA_LIB/core/utils/log.sh"
source "$REMEDIA_LIB/core/utils/debug.sh"
source "$REMEDIA_LIB/core/config.sh"
source "$REMEDIA_LIB/core/user_context.sh"
source "$REMEDIA_LIB/core/storage.sh"

source "$REMEDIA_LIB/core/state.sh"
state_init

source "$REMEDIA_LIB/core/bootstrap.sh"

# 🚀 MAIN FLOW
runtime_init

runtime_require REMEDIA_LIB
runtime_require CACHE_DIR
runtime_require BACKUP_STORAGE
runtime_require FAST_STORAGE
runtime_require SLOW_STORAGE
runtime_require PROJECT_DIR

runtime_boot

[[ "$RUNTIME_STATE" == "INIT" ]] || {
    echo "[FATAL] boot failed or skipped init"
    exit 1
}

runtime_mark_ready

# 🟣 FINAL PHASE
source "$REMEDIA_LIB/core/runtime_env.sh"
source "$REMEDIA_LIB/core/version.sh"
source "$REMEDIA_LIB/core/hooks.sh"

runtime_assert_ready
