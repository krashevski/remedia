#!/usr/bin/env bash
# modules/demo/modules/cinema/steps/01_create_dir.sh


do_step() {
    mkdir -p /tmp/demo_tx
    echo "created dir"
}

undo_step() {
    rm -rf /tmp/demo_tx
    echo "removed dir"
}
