#!/usr/bin/env bash
# modules/system/modules/man/install.sh

man_install() {
    log_debug "[DEBUG] HIT5 man_install"
    log_debug "[DEBUG MAN] UID=$(id -u)"

    echo "Remedia System Man module"
    echo

    # --------------------------------------------------------
    # ROOT CHECK
    # --------------------------------------------------------

    if (( EUID != 0 )); then
        echo "[ERROR] Installing system man pages requires root privileges."
        return 1
    fi

    echo "[MAN] [INSTALL] installing man pages..."

    local locales=("en" "ru" "ja" "kz")
    local sections=("man1" "man8")

    local lang section src_dir target_dir
    local f base installed=0

    # --------------------------------------------------------
    # INSTALL MAN PAGES
    # --------------------------------------------------------

    for lang in "${locales[@]}"; do
        for section in "${sections[@]}"; do

            if [[ "$lang" == "en" ]]; then
                src_dir="$MODULE_DIR/modules/man/$section"
                target_dir="/usr/share/man/$section"
            else
                src_dir="$MODULE_DIR/modules/man/$lang/$section"
                target_dir="/usr/share/man/$lang/$section"
            fi

            # Skip missing directories
            if [[ ! -d "$src_dir" ]]; then
                log_debug "[MAN] missing directory: $src_dir"
                continue
            fi

            mkdir -p "$target_dir" || {
                echo "[ERROR] Cannot create: $target_dir"
                return 1
            }

            # Install files corresponding to section number
            local ext="${section#man}"

            for f in "$src_dir"/*."$ext"; do
                [[ -f "$f" ]] || continue

                base="$(basename "$f")"

                if ! install -m 644 "$f" "$target_dir/$base"; then
                    echo "[ERROR] Failed to install: $base"
                    return 1
                fi

                if ! gzip -f "$target_dir/$base"; then
                    echo "[ERROR] Failed to compress: $base"
                    return 1
                fi

                echo "[OK] $lang / $section → $base.gz"
                ((installed+=1))

            done
        done
    done

    # --------------------------------------------------------
    # UPDATE MAN DATABASE
    # --------------------------------------------------------

    echo
    echo "[MAN] [INSTALL] installed pages: $installed"

    if (( installed == 0 )); then
        echo "[WARN] No man pages found for installation."
        return 1
    fi

    echo "[MAN] [INSTALL] updating database..."

    if ! mandb -q; then
        echo "[ERROR] Failed to update man database."
        return 1
    fi

    echo "[MAN] [INSTALL] system database updated"
    echo "[MAN] [INSTALL] done"
}
