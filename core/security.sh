#!/usr/bin/env bash
# core/security.sh

require_root() {
    log_debug "[DEBUG REQ] UID=$(id -u)"
    [[ "$(id -u)" -eq 0 ]]
}
