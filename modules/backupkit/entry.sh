#!/usr/bin/env bash
# modules/backupkit/entry.sh
set -euo pipefail

MODULE_NAME="backupkit"
MODULE_DESC="backupkit tools"

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# env FIRST
source "$MODULE_DIR/core/env.sh"

# CORE
source "$MODULE_DIR/core/logger.sh"
source "$MODULE_DIR/core/security.sh"

# HOME MODULE
source "$MODULE_DIR/modules/home/archive/tar.sh"
source "$MODULE_DIR/modules/home/snapshot/rsync.sh"
source "$MODULE_DIR/modules/home/restore/modes.sh"
source "$MODULE_DIR/modules/home/health/self_heal.sh"
source "$MODULE_DIR/modules/home/verify.sh"
source "$MODULE_DIR/modules/home/meta.sh"
source "$MODULE_DIR/modules/home/restore.sh"
source "$MODULE_DIR/modules/home/removal.sh"
source "$MODULE_DIR/modules/home/backup.sh"
source "$MODULE_DIR/modules/home/doctor.sh"
source "$MODULE_DIR/modules/home/module.sh"

# INIT MODULE
source "$MODULE_DIR/modules/init/user_fs.sh"
source "$MODULE_DIR/modules/init/fs_bootstrap.sh"
source "$MODULE_DIR/modules/init/init_backupkit.sh"
source "$MODULE_DIR/modules/init/user_add.sh"

# REGISTRY MODULE
source "$MODULE_DIR/modules/registry/registry.sh"
source "$MODULE_DIR/modules/registry/user_remove.sh"
source "$MODULE_DIR/modules/registry/module.sh"

# FIREFOX MODULE
source "$MODULE_DIR/modules/firefox/firefox.sh"
source "$MODULE_DIR/modules/firefox/module.sh"

# BACKOUPKIT MODULE
source "$MODULE_DIR/module.sh"
