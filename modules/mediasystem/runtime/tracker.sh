#!/usr/bin/env bash
# Remedia Execution Tracker v1

# -------------------------
# INIT CONTEXT
# -------------------------
: "${REMEDIA_CTX_APP:=unknown_app}"
: "${REMEDIA_CTX_STAGE:=init}"
: "${REMEDIA_CTX_STEP:=0}"
: "${REMEDIA_CTX_PIPELINE_ID:=unknown}"
: "${REMEDIA_DEBUG:=0}"

track_set_app() {
    REMEDIA_CTX_APP="$1"
    export REMEDIA_CTX_APP
}

track_set_stage() {
    REMEDIA_CTX_STAGE="$1"
    export REMEDIA_CTX_STAGE
}

track_step() {
    ((REMEDIA_CTX_STEP++))
}

track_log() {
    local msg="$1"
    echo "[TRACK] app=${REMEDIA_CTX_APP} stage=${REMEDIA_CTX_STAGE} step=${REMEDIA_CTX_STEP} :: $msg"
}

track_exec() {
    local name="$1"
    shift

    if [[ "${REMEDIA_DEBUG}" == "1" ]]; then
        echo "[DEBUG] RUN: $*"
    fi

    set +e
    "$@"
    local rc=$?
    set -e

    if [[ "${REMEDIA_DEBUG}" == "1" ]]; then
        echo "[DEBUG] RC=$rc"
    fi

    if [[ $rc -ne 0 ]]; then
        echo "[TRACK] FAIL: $name (exit=$rc)"
        return $rc
    fi

    echo "[TRACK] OK: $name"
    return 0
}
