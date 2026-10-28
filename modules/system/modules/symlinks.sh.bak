#!/usr/bin/env bash
# modules/system/modules/symlinks.sh

# -------------------------------------------------------------
# 0. Entry point (UCC compliant)
# -------------------------------------------------------------

cmd_symlinks_run() {
    system_symlinks_run "$@"
}

# -------------------------------------------------------------
# 1. Core
# -------------------------------------------------------------

system_symlinks_run() {
    info "Symlinks: start"

    local BASE_DIR="/mnt/storage"
    local TARGET_HOME
    TARGET_HOME="$(resolve_target_home)" || return 1

    # --- language detect ---
    local lang="${LANG%%_*}"
    lang="${lang,,}"

    # --- config bind ---
    declare -n LINK_NAMES="LINK_NAMES_${lang}"

    # fallback → en
    if ! declare -p LINK_NAMES &>/dev/null; then
        declare -n LINK_NAMES="LINK_NAMES_en"
    fi

    # ---------------------------------------------------------
    # 2. Declarative config
    # ---------------------------------------------------------

    declare -A TARGET_DIRS=(
        [music]="Music"
        [pictures]="Pictures"
        [videos]="Videos"
    )

    declare -a EXTRA_SYMLINKS=(
        # "Downloads:/mnt/storage/Downloads"
    )

    # --- localization ---
    declare -A LINK_NAMES_ru=(
        [music]="Музыка"
        [pictures]="Изображения"
        [videos]="Видео"
    )

    declare -A LINK_NAMES_en=(
        [music]="Music"
        [pictures]="Pictures"
        [videos]="Videos"
    )

    declare -A LINK_NAMES_ja=(
        [music]="音楽"
        [pictures]="画像"
        [videos]="動画"
    )

    # ---------------------------------------------------------
    # 3. Main logic (pure declarative)
    # ---------------------------------------------------------

    for key in "${!TARGET_DIRS[@]}"; do
        local target="$BASE_DIR/${TARGET_DIRS[$key]}"
        local link_name
        link_name="$(get_link_name "$key" LINK_NAMES LINK_NAMES_en)"

        local link_path="$TARGET_HOME/$link_name"

        ensure_dir "$target"
        ensure_symlink "$link_path" "$target"
    done

    for pair in "${EXTRA_SYMLINKS[@]}"; do
        [[ "$pair" == *:* ]] || {
            warn "Invalid symlink format: $pair"
            continue
        }

        local name="${pair%%:*}"
        local target="${pair##*:}"
        local link_path="$TARGET_HOME/$name"

        ensure_dir "$target"
        ensure_symlink "$link_path" "$target"
    done

    info "Symlinks: done"
}

# -------------------------------------------------------------
# 4. Primitives
# -------------------------------------------------------------

get_link_name() {
    local key="$1"
    local primary_ref="$2"
    local fallback_ref="$3"

    declare -n primary="$primary_ref"
    declare -n fallback="$fallback_ref"

    echo "${primary[$key]:-${fallback[$key]}}"
}

ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

ensure_symlink() {
    local link="${1:?missing link}"
    local target="${2:?missing target}"

    # already correct
    if [[ -L "$link" && "$(realpath -m "$link")" == "$(realpath -m "$target")" ]]; then
        info "skip (ok): $link"
        return
    fi

    # empty dir → replace silently
    if [[ -d "$link" && -z "$(find "$link" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
        rm -rf "$link"
        ln -s "$target" "$link"
        info "linked: $link → $target"
        return
    fi

    # non-empty dir
    if [[ -d "$link" ]]; then
        if ui_confirm_policy "ask" "Replace directory $link?"; then
            rm -rf "$link"
            ln -s "$target" "$link"
            info "replaced dir: $link → $target"
        else
            warn "skip: $link"
        fi
        return
    fi

    # file conflict
    if [[ -e "$link" ]]; then
        warn "conflict: $link"
        return
    fi

    ln -s "$target" "$link"
    info "linked: $link → $target"
}

# -------------------------------------------------------------
# 5. Logging (fallback-safe)
# -------------------------------------------------------------

info() {
    printf "[INFO] %s\n" "$*"
}

warn() {
    printf "[WARN] %s\n" "$*" >&2
}

