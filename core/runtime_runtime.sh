#!/usr/bin/env bash
# core/runtime_runtime.sh

set -euo pipefail

RUNTIME_READY=0

runtime_mark_ready() {
    RUNTIME_READY=1
}

runtime_assert_ready() {
    [[ "${RUNTIME_READY:-0}" == "1" ]] || {
        echo "[RUNTIME v3 FATAL] runtime not ready"
        return 1
    }
}
