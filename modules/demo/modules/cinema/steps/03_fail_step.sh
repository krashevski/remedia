

do_step() {
    echo "this step will fail"
    exit 1
}

undo_step() {
    echo "nothing to undo"
}
