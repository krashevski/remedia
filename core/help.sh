#!/usr/bin/env bash
# core/help.sh

set -euo pipefail

remedia_help() {
echo "Available commands:"
echo

# core
printf "  %-12s → %s\n" "setup"  "configure system"
printf "  %-12s → %s\n" "doctor" "check system health"

# modules
for module_dir in "$REMEDIA_LIB/modules"/*; do
    [[ -d "$module_dir" ]] || continue

    meta="$module_dir/module.meta"
    [[ -f "$meta" ]] || continue

    name=""
    desc=""

    while IFS='=' read -r k v; do
        case "$k" in
            NAME) name="$v" ;;
            DESC) desc="$v" ;;
        esac
    done < "$meta"

    [[ -n "$name" ]] || name="$(basename "$module_dir")"

    printf "  %-12s → %s\n" "$name" "${desc:-module}"
done | sort

echo
echo "Usage:"
echo "  remedia <command> [args]"
echo
echo "Quick start UI:"
echo "  remedia system center"
echo
}

remedia_module_help() {
    local module="$1"
    local parent="${2:-}"

    local dir

    if [[ -n "$parent" ]]; then
        dir="$REMEDIA_LIB/modules/$parent/modules/$module"
    else
        dir="$REMEDIA_LIB/modules/$module"
    fi

    [[ -d "$dir" ]] || {
        echo "[ERROR] unknown module: $module"
        return 1
    }

    echo
    echo "Module: $module"

    # DESCRIPTION
    local meta="$dir/module.meta"
    if [[ -f "$meta" ]]; then
        while IFS='=' read -r k v; do
            [[ "$k" == "DESC" ]] && echo "$v"
        done < "$meta"
    else
        echo "(no description)"
    fi

    echo
    echo "Commands:"

    # COMMANDS
    local cmds="$dir/commands.meta"

    if [[ -f "$cmds" ]]; then
        while IFS='=' read -r cmd desc; do
            printf "  %-14s → %s\n" "$cmd" "$desc"
        done < "$cmds"
    else
        for f in "$dir"/*.sh; do
            [[ -f "$f" ]] || continue
            cmd="$(basename "$f" .sh)"
            printf "  %-14s → %s\n" "$cmd" "(undocumented)"
        done | sort
    fi

    echo
    echo "Usage:"
    if [[ -n "$parent" ]]; then
        echo "  remedia $parent $module <command>"
    else
        echo "  remedia $module <command>"
    fi
    echo
}


