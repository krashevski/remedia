#!/usr/bin/env bash
# modules/mediasystem/entry.sh

MODULE_NAME="mediasystem"
MODULE_DESC="mediasystem tools"

export MODULE_DIR="${MODULE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# DOCTOR MODULE
source "$MODULE_DIR/modules/doctor/doctor.sh"

# CLI USE
source "$MODULE_DIR/module.sh"

