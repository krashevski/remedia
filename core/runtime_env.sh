#!/usr/bin/env bash
# core/runtime_env.sh

runtime_env_lock() {
    readonly REMEDIA_LIB
    readonly CACHE_DIR
    readonly BACKUP_STORAGE
    readonly FAST_STORAGE
    readonly SLOW_STORAGE
    readonly PROJECT_DIR
}
