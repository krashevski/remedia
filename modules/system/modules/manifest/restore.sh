#!/usr/bin/env bash
# # modules/system/modules/manifest/restore.sh 

system_doctor_run() {
    local action="${1:-}"
    shift || true

    case "$action" in
        verify|plan|restore)
            system_doctor_"$action" "$@"
            ;;
        *)
            echo "[DOCTOR] usage: verify|plan|restore"
            return 1
            ;;
    esac
}

system_doctor_verify() {
    local root="${1:-}"
    
    [[ -n "$root" ]] || {
        echo "Remedia System Manifest module"
        echo
        echo "[MANIFEST] [VERIFY] missing src directory"
        echo
        echo "Usage:"
        echo "  remedia system manifest verify <directory>"
        return 1
    }
        
    if [[ -z "$root" ]]; then
        root="$(pwd)"
    fi
    
    [[ -d "$root" ]] || {
        echo "[VERIFY] invalid root: $root"
        return 1
    }
    
    local manifest="${2:-}"

    # 🔹 auto-resolve manifest
    auto_resolve_manifest
    [[ -n "$manifest" ]] || {
        echo "[VERIFY] manifest required"
        return 1
    }

    [[ -f "$manifest" ]] || {
        echo "[VERIFY] manifest not found: $manifest"
        return 1
    }

    echo "[VERIFY] using: $manifest"

    local total=0
    local ok=0
    local changed=0
    local missing=0
    local errors=0
    local new=0
    declare -A manifest_map
    
    echo "[VERIFY] scanning..."
    
    while read -r hash file; do
        file="${file#./}"
        manifest_map["$file"]=1
        
        ((total+=1)) || true

        local path="$root/$file"

        if [[ ! -f "$path" ]]; then
            echo "[MISSING] $file"
            ((missing+=1)) || true
            continue
        fi

        local current
        if ! current=$(timeout 2 sha256sum "$path" 2>/dev/null | awk '{print $1}'); then
            echo "[ERROR] cannot hash: $file"
            ((errors+=1)) || true
            continue
        fi

        if [[ "$current" == "$hash" ]]; then
            ((ok+=1)) || true
        else
            echo "[CHANGED] $file"
            ((changed+=1)) || true
        fi
        ((total % 100 == 0)) && echo "[VERIFY] $total files checked..."
    done < "$manifest" 
    
    # NEW FILES DETECTION
    while IFS= read -r -d '' f; do
        rel="${f#"$root/"}"

        if [[ -z "${manifest_map[$rel]:-}" ]]; then
            echo "[NEW] $rel"
            ((new+=1)) || true
        fi
    done < <(find "$root" -type f -print0)
    
    # 🔹 QUIET MODE
    if [[ "${BACKUPKIT_QUIET:-0}" == "1" && $changed -eq 0 && $missing -eq 0 && $errors -eq 0 && $new -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo "[VERIFY SUMMARY]"
    echo "total:   $total"
    echo "ok:      $ok"    
    echo "changed: $changed"
    echo "missing: $missing"
    echo "errors:  $errors"

    if [[ $changed -eq 0 && $missing -eq 0 && $errors -eq 0 ]]; then
        return 0
    else
        return 0   # <- важно!
    fi
}

system_doctor_plan() {
    local root="${1:-}"
    
    [[ -n "$root" ]] || {
        echo "Remedia System Manifest module"
        echo
        echo "[MANIFEST] [PLAN] missing src directory"
        echo
        echo "Usage:"
        echo "  remedia system manifest plan <directory>"
        return 1
    }
    
    local manifest="${2:-}"
    
    auto_resolve_manifest
    [[ -n "$manifest" ]] || {
        echo "[PLAN] manifest required"
        return 1
    }

    [[ -f "$manifest" ]] || {
        echo "[PLAN] manifest not found: $manifest"
        return 1
    }

    declare -A manifest_map
    declare -a missing_files
    declare -a changed_files

    while read -r hash file; do
        manifest_map["$file"]="$hash"

        local path="$root/$file"

        if [[ ! -f "$path" ]]; then
            missing_files+=("$file")
            continue
        fi

        local current
        current=$(sha256sum "$path" | awk '{print $1}')

        if [[ "$current" != "$hash" ]]; then
            changed_files+=("$file")
        fi
    done < "$manifest"

    echo "[PLAN]"
    echo "missing:${missing_files[*]}"
    echo "changed:${changed_files[*]}"
}


system_doctor_restore() {
    local root="$1"
    local manifest="$2"
    local backup_root="${BACKUP_STORAGE:-/mnt/backups}"

    echo "[RESTORE] starting self-heal"

    while read -r hash file; do
        local target="$root/$file"

        # если файл норм → пропуск
        [[ -f "$target" ]] && {
            current=$(sha256sum "$target" | awk '{print $1}')
            [[ "$current" == "$hash" ]] && continue
        }

        echo "[RESTORE] fixing $file"

        # ищем в backup (простая стратегия)
        local source
        source=$(find "$backup_root" -type f -path "*/snapshot/$file" | head -n 1)

        if [[ -n "$source" ]]; then
            mkdir -p "$(dirname "$target")"
            cp "$source" "$target"
        else
            echo "[WARN] no backup for $file"
        fi

    done < "$manifest"

    echo "[RESTORE] done"
}
