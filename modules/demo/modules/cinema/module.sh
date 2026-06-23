#!/usr/bin/env bash
# modules/demo/modules/cinema/module.sh 

demo_cinema_run() {
    local sub="${1:-}"

    case "$sub" in
        run)           
            echo "Demo Cinema module"
            echo ""
            echo "DEBUG STEPS=${STEPS[*]:-EMPTY}"
            echo "DEBUG STATE_FILE=${STATE_FILE:-EMPTY}"
            main_cinema
            ;;
        replay)
            echo "Demo Cinema module"
            echo ""
            replay
            ;;
        scrub) 
            echo "Demo Cinema module"
            echo ""
            scrub 
            ;;
        *)
            echo "Demo Cinema module"
            echo
            echo "Usage:" 
            echo "  remedia demo cinema <command>"
            echo
            echo "Commands:"
            echo "  run" 
            echo "  replay"
            echo "  scrub"
            return 0
            ;;
    esac
}
