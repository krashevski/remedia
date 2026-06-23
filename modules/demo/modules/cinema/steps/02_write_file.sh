

do_step() {
    echo "hello transaction" > /tmp/demo_tx/file.txt
    echo "file written"
}

undo_step() {
    rm -f /tmp/demo_tx/file.txt
    echo "file removed"
}
