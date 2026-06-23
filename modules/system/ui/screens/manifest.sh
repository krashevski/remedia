#!/usr/bin/env bash
# modules/system/ui/screens/manifest.sh

screen_manifest() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                   ${COLOR_BOLD}${COLOR_CYAN} MANIFEST ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "Module for filesystem state manifest management in panic-level conditions, providing continuous observation, integrity verification, and recovery planning when system behavior becomes unreliable and root cause cannot be determined."
        echo
        echo "Manifest acts as a trust anchor when the system becomes unreliable"
        echo
        echo "1) Manifest generate for directory"
        echo "2) List manifests"
        echo "3) Doctor manifest verify"
        echo "4) Doctor plan to restore"
#        echo "9) Doctor restore"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Select [1-#]: " c

        case "$c" in
            1)
                src="$(ui_input "Enter source path for manifest")"
                system_manifest_generate "$src"
                ;;
            2)
                system_manifest_run list
                ;;
            3)
                root="$(ui_input "Enter source path to verify")"

#                manifest="$(get_manifest "$root" || true)"

#                if [[ -z "$manifest" ]]; then
#                    echo "[ERROR] manifest not found for: $root"
#                    return 1
#                fi

               auto_resolve_manifest
               system_doctor_verify "$root" "$manifest"
               ;;
            4)
               root="$(ui_input "Enter source path to plan from manifest")"

#               manifest="$(get_manifest "$root" || true)"

#               if [[ -z "$manifest" ]]; then
#                   echo "[ERROR] manifest not found for: $root"
#                   return 1
#               fi

               auto_resolve_manifest
               system_doctor_plan "$root" "$manifest"
               ;;
#           5)
#               root="$(ui_input "Enter path to restore")"
#               remedia system doctor restore "$root"
#               ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp "Press Enter..."
    done
}
