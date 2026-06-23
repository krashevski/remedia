#!/usr/bin/env bash
# modules/modules/home/archive/tar.sh

set -euo pipefail

create_cold_archive() {
    local src="$1"
    local archive="$2"

    tar -I zstd \
        --numeric-owner \
        --xattrs \
        --acls \
        --warning=no-file-ignored \
        -cf "$archive" \
        -C "$src" .
}
