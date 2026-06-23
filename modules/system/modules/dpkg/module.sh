#!/usr/bin/env bash
# modules/system/modules/dpkg/module.sh

system_dpkg_run() {
    local sub="${1:-}"
    shift || true

    case "$sub" in
        doctor)
            dpkg_doctor "$@"
            ;;
        fix)
            dpkg_fix "$@"
            ;;
        upgrade)
            dpkg_upgrade "$@"
            ;;
        full-upgrade)
            dpkg_full_upgrade "$@"
            ;;
        heal)
            dpkg_heal "$@"
            ;;
        *)
            local module="dpkg"
            local dir="system"
            remedia_module_help "$module" "$dir"
            ;;
    esac
}
