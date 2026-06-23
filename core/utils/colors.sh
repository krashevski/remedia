#!/usr/bin/env bash
# core/utils/colors.sh - PALETTE ONLY

if [[ -t 1 && -t 2 && "${NO_COLOR:-0}" != "1" ]]; then
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_CYAN=$'\033[36m'
    COLOR_RED=$'\033[31m'
    COLOR_BLUE=$'\033[34m'
    COLOR_MAGENTA=$'\033[35m'
    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\e[1m'
else
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_CYAN=""
    COLOR_RED=""
    COLOR_BLUE=""
    COLOR_MAGENTA=""
    COLOR_RESET=""
    COLOR_BOLD=""
fi

export COLOR_GREEN COLOR_YELLOW COLOR_CYAN COLOR_RED COLOR_BLUE COLOR_MAGENTA COLOR_RESET COLOR_BOLD
