#!/usr/bin/env bash
# modules/system/ui/policy.sh

# policies:
# ask | force | skip | silent
ui_policy_decision() {
    local policy="$1"

    case "$UI_MODE:$policy" in
        silent:*) echo "NO" ;;
        *:force)  echo "YES" ;;
        *:skip)   echo "NO" ;;
        *)        echo "ASK" ;;
    esac
}

ui_confirm_policy() {
    local policy="$1"
    local prompt="$2"

    case "$(ui_policy_decision "$policy")" in
        YES) return 0 ;;
        NO)  return 1 ;;
        ASK) ui_confirm "$prompt" ;;
    esac
}
