#!/usr/bin/env bash
# modules/system/core/checks.sh

check_module() {
    local name="$1"

    if [[ -d "$REMEDIA_LIB/modules/$name" ]]; then
        echo "✔ $name"
    else
        echo "✖ $name"
    fi
}
