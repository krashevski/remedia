#!/usr/bin/env bash
# modules/system/moduels/man/install.sh
   
man_install() {
    log_debug "[DEBUG] HIT5 man_install"
    log_debug "[DEBUG MAN] UID=$(id -u)"

    echo "Remedia System Man module"
    echo

    echo "[MAN] [INSTALL] installing man pages..."

    local locales=("en" "ru" "ja") 
    
    for lang in "${locales[@]}"; do 
        if [[ "$lang" == "en" ]]; then 
            SRC_DIR="$MODULE_DIR/man/man8" 
            TARGET_DIR="/usr/share/man/man8" 
        else 
            SRC_DIR="$MODULE_DIR/man/$lang/man8" 
            TARGET_DIR="/usr/share/man/$lang/man8" 
        fi 
        
        [[ -d "$SRC_DIR" ]] || {
            echo "[WARN] missing: $SRC_DIR"
            continue
        }
        
        mkdir -p "$TARGET_DIR" 
        
        for f in "$SRC_DIR"/*.8; do 
            [[ -f "$f" ]] || continue 
            
            local base 
            base="$(basename "$f")" 
            cp "$f" "$TARGET_DIR/$base" 
            gzip -f "$TARGET_DIR/$base" 
            echo "[OK] $lang → $base" 
         done 
    done 
    
    echo "[MAN] [INSTALL] updating database..." 
    mandb 
    echo "[MAN] [INSTALL] system database updated" 
            
    echo "[MAN] [INSTALL] done"
}
