#!/usr/bin/env bash
# modules/system/entry.sh

MODULE_NAME="system"
MODULE_DESC="system tools"

# critical dirs (always safe)
export REMEDIA_VAR="${REMEDIA_VAR:-$HOME/.remedia}"
mkdir -p "$REMEDIA_VAR"
export SYSTEM_VAR="$REMEDIA_VAR/system"
mkdir -p "$SYSTEM_VAR"

export MODULE_DIR="${MODULE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# UI LAYER
source "$MODULE_DIR/ui/core.sh"
source "$MODULE_DIR/ui/backend.sh"
source "$MODULE_DIR/ui/policy.sh"
source "$MODULE_DIR/ui/input.sh"
source "$MODULE_DIR/ui/confirm.sh"
source "$MODULE_DIR/ui/select.sh"
source "$MODULE_DIR/ui/menu.sh"
source "$MODULE_DIR/ui/render.sh"

# UI COMPONENTS
source "$MODULE_DIR/ui/components/header.sh"
source "$MODULE_DIR/ui/components/status_block.sh"
source "$MODULE_DIR/ui/components/menu.sh"
source "$MODULE_DIR/ui/components/footer.sh"

# UI API
source "$MODULE_DIR/core/checks.sh"

# UI SCREENS
source "$MODULE_DIR/ui/screens/system.sh"
source "$MODULE_DIR/ui/screens/users_home.sh"
source "$MODULE_DIR/ui/screens/man.sh"
source "$MODULE_DIR/ui/screens/manifest.sh"
source "$MODULE_DIR/ui/screens/mediasystem_run.sh"
source "$MODULE_DIR/ui/screens/mediapanel.sh"
source "$MODULE_DIR/ui/screens/backupkit.sh"
source "$MODULE_DIR/ui/screens/backupkit_firefox.sh"
source "$MODULE_DIR/ui/screens/backupkit_userhome.sh"
source "$MODULE_DIR/ui/screens/backupkit_users.sh"
source "$MODULE_DIR/ui/screens/cuda_tools.sh"
source "$MODULE_DIR/ui/screens/dpkg.sh"
source "$MODULE_DIR/ui/screens/cinema.sh"

# DOCTOR MODULE
source "$MODULE_DIR/modules/doctor/doctor.sh"

# MAN MODULE
source "$MODULE_DIR/modules/man/module.sh"
source "$MODULE_DIR/modules/man/install.sh"
source "$MODULE_DIR/modules/man/doctor.sh"
source "$MODULE_DIR/modules/man/open.sh"
source "$MODULE_DIR/modules/man/module.sh"

# HOME MODULE
source "$MODULE_DIR/modules/home/doctor.sh"
source "$MODULE_DIR/modules/home/fix.sh"
source "$MODULE_DIR/modules/home/heal.sh"
source "$MODULE_DIR/modules/home/module.sh"

# DPKG MODULE
source "$MODULE_DIR/modules/dpkg/doctor.sh"
source "$MODULE_DIR/modules/dpkg/fix.sh"
source "$MODULE_DIR/modules/dpkg/upgrade.sh"
source "$MODULE_DIR/modules/dpkg/heal.sh"
source "$MODULE_DIR/modules/dpkg/module.sh"
            
# MANIFEST MODULE
source "$MODULE_DIR/modules/manifest/manifest.sh"
source "$MODULE_DIR/modules/manifest/common.sh"
source "$MODULE_DIR/modules/manifest/restore.sh"
source "$MODULE_DIR/modules/manifest/module.sh"

# SYMLINKS MODULE
source "$MODULE_DIR/modules/symlinks.sh"

# CUDA-TOOLS MODULE
source "$MODULE_DIR/modules/cuda-tools/cuda_tools.sh"
source "$MODULE_DIR/modules/cuda-tools/module.sh"

# UI USE
source "$MODULE_DIR/ui/ui.sh"

# CLI USE
source "$MODULE_DIR/module.sh"
