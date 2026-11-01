#!/usr/bin/env bash
# core/help.sh
set -euo pipefail

remedia_help_init_i18n() {
    if ! declare -F i18n_load >/dev/null; then
        # shellcheck source=core/i18n.sh
        source "$REMEDIA_LIB/core/i18n.sh" || return 1
    fi
    i18n_load "$REMEDIA_LIB/core/i18n" || return 1
}

remedia_help() {
    remedia_help_init_i18n || return 1
    local module_dir meta name desc k='' v=''
    t CORE_HELP_AVAILABLE
    echo
    printf '  %-12s → %s\n' setup "$(t CORE_HELP_SETUP)"
    printf '  %-12s → %s\n' doctor "$(t CORE_HELP_DOCTOR)"
    for module_dir in "$REMEDIA_LIB/modules"/*; do
        [[ -d "$module_dir" ]] || continue
        meta="$(i18n_meta_path "$module_dir" module.meta)" || continue
        name='' desc=''
        while IFS='=' read -r k v || [[ -n "$k" ]]; do
            case "$k" in
                NAME) name="$v" ;;
                DESC) desc="$v" ;;
                *) : ;;
            esac
        done < "$meta"
        [[ -n "$name" ]] || name="$(basename "$module_dir")"
        printf '  %-12s → %s\n' "$name" "${desc:-$(t CORE_HELP_MODULE_FALLBACK)}"
    done | sort
    echo
    t CORE_HELP_USAGE
    t CORE_HELP_USAGE_ROOT
    echo
    t CORE_HELP_QUICK_START
    echo '  remedia system center'
    echo
}

remedia_module_help() {
    remedia_help_init_i18n || return 1
    local module="$1" parent="${2:-}" dir meta cmds file
    local k='' v='' cmd='' desc=''
    if [[ -n "$parent" ]]; then
        dir="$REMEDIA_LIB/modules/$parent/modules/$module"
    else
        dir="$REMEDIA_LIB/modules/$module"
    fi
    if [[ ! -d "$dir" ]]; then
        t CORE_HELP_UNKNOWN_MODULE "$module"
        return 1
    fi
    echo
    t CORE_HELP_MODULE "$module"
    if meta="$(i18n_meta_path "$dir" module.meta)"; then
        while IFS='=' read -r k v || [[ -n "$k" ]]; do
            # Avoid a false status on NAME/CATEGORY under set -e.
            case "$k" in
                DESC) printf '%s\n' "$v" ;;
                *) : ;;
            esac
        done < "$meta"
    else
        t CORE_HELP_NO_DESCRIPTION
    fi
    echo
    t CORE_HELP_COMMANDS
    if cmds="$(i18n_meta_path "$dir" commands.meta)"; then
        while IFS='=' read -r cmd desc || [[ -n "$cmd" ]]; do
            [[ -n "$cmd" && "$cmd" != \#* ]] || continue
            printf '  %-14s → %s\n' "$cmd" "$desc"
        done < "$cmds"
    else
        for file in "$dir"/*.sh; do
            [[ -f "$file" ]] || continue
            cmd="$(basename "$file" .sh)"
            printf '  %-14s → %s\n' "$cmd" "$(t CORE_HELP_UNDOCUMENTED)"
        done | sort
    fi
    echo
    t CORE_HELP_USAGE
    if [[ -n "$parent" ]]; then
        t CORE_HELP_USAGE_NESTED "$parent" "$module"
    else
        t CORE_HELP_USAGE_MODULE "$module"
    fi
    echo
}
