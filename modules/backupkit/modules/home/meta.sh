#!/usr/bin/env bash
# backupkit/modules/home/meta.sh

write_meta() {
    local id="$1"
    local path="$2"
    local has_archive="${3:-false}"

    cat > "$path/meta.json" <<EOF
{
  "id": "$id",
  "type": "snapshot",
  "layers": {
    "snapshot": true,
    "archive": $has_archive
  },
  "created_at": "$(date -Iseconds)"
}
EOF
}

get_meta_field() {
    local file="$1"
    local key="$2"

    grep -oP "\"$key\":\s*\"\K[^\"]+" "$file"
}

meta_has_archive() {
    local file="$1"

    grep -q '"archive": true' "$file"
}

meta_get() {
    local key="$1"
    local file="$2"
    jq -r ".$key" "$file"
}


