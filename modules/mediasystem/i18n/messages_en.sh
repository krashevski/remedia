#!/usr/bin/env bash
# =============================================================
# PRODUCTION MEDIA PANEL — MIT License
# Copyright (c) 2025 Vladislav Krashevsky
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, subject to the following:
# The above copyright notice and this permission notice shall
# be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
# =============================================================
# messages_en.sh
# PRODUCTION MEDIA PANEL — Messages Library
# Unified messages for all scripts in english
# MIT License — Copyright (c) 2025 Vladislav Krashevsky support ChatGPT
# ==============================================================

MSG[hello]="Hello, world!"
MSG[start]="Starting"

# common library
# logging.sh
MSG[man_not_installed_hint]="Man pages are not installed. Install them from the Settings menu."
# privileges.sh
MSG[run_sudo]="The script must be run with root privileges (sudo)"
MSG[exec_via_sudo]="Attempting to execute via sudo..."
# cleanup.sh
MSG[clean_ok]="Temporary files deleted."
MSG[clean_tmp]="Cleaning temporary files..."
MSG[clean_invalid_dir]="Invalid directory: %s"
MSG[msg_cleanup_start]="Cleaning temporary files"
MSG[msg_cleanup_done]="Cleaning complete"
MSG[msg_removing]="Removing"
MSG[msg_unsafe_path]="Unsafe path, operation canceled"
MSG[msg_workdir_cleaning]="Cleaning working directory: %s..."
MSG[msg_workdir_cleaned]="Working directory %s has been cleaned successfully."
# guards-firefox.sh
MSG[firefox_closing]="Firefox is closing, please wait ..."
MSG[firefox_stop]="Firefox still running → forcing stop"
# guards-inhibit.sh
MSG[inhibit_not_found]="systemd-inhibit not found, skipping inhibit"
MSG[inhibit_failed]="Failed to inhibit, continuing anyway"
# select_user.sh
MSG[user_no_home]="No users in /home"
MSG[user_available]="Available users:"
MSG[user_select]="Select user(s) for operation "%s" (for example: 1 or 1 3): "
MSG[user_invalid_select]="Ignoring invalid selection: %s"
MSG[user_no_selected]="No users selected"
# system_detect.sh
MSG[detect_system]="Detected system: %s %s"
MSG[not_system]="Cannot detect system (no /etc/os-release)"
# deps.sh
MSG[deps_ok]="All dependencies installed"
MSG[deps_install_try]="Attempt automatic installation…"
MSG[deps_unknown_manager]="Unknown package manager. Install manually: %s"
MSG[deps_missing_list]="Missing dependencies: %s"
MSG[deps_missing]="Package not installed. Install it"
# run-step
MSG[step_ok]="%s — completed successfully"
MSG[step_fail]="%s — failed (see %s)"
MSG[step_not_function]="'%s' is not a function"
MSG[step_extract]="Extracting archive"
MSG[step_repos]="Restoring repositories and keyrings"
MSG[step_packages]="Restoring packages"
MSG[step_logs]="Restoring logs"
MSG[step_archive]="Archive"
MSG[step_system_packages]="System packages"
MSG[step_repos_and_keys]="APT sources and keys"
MSG[step_logs]="Logs"
MSG[step_user_packages]="Packages installed by the user"
MSG[spet_archive]="Archive"
MSG[step_backup_fail]="Backup failed"
# init.sh
MSG[init_start]="Initializing directories"
MSG[dir_created]="Directory created"
MSG[dir_exists]="Directory already exists"
MSG[dir_create_failed]="Failed to create directory"
MSG[dir_empty]="Empty directory path"
MSG[msg_init_user_dirs]="Initializing user directories"
MSG[msg_init_system_dirs]="Initializing system directories"
MSG[msg_unsafe_path]="Unsafe path"
MSG[msg_run_sudo]="Requires root privileges (run with sudo)"
# install-man.sh
MSG[man_not_found]="REBK man pages not found, installing..."
MSG[man_installed]="Man pages installed successfully"
MSG[man_install_sudo]="Root is required to install man pages. Use sudo."
MSG[error_run_root]="Error: Script must be run with root privileges."
MSG[man_install_start]="==== REBK man installation started: %s ===="
MSG[directory_not_found]="Directory %s not found. Skipping."
MSG[man_installed]="Installed man page [%s]: %s.gz"
MSG[updating_mandb]="Updating mandb database..."
MSG[install_completed]="==== REBK man installation completed: %s ===="

# install.sh

# menu.sh, mediapanel
MSG[menu_home_not]="ERROR: Cannot determine home directory for user"
MSG[menu_dir_not]="ERROR: Package directory not found:"
MSG[menu_modules_dir_not]="ERROR: Modules directory not found:"
MSG[menu_mediasystem_title]="REINCARNATION PIPELINE"
MSG[menu_sel_mode]="Select pipeline mode:"
MSG[menu_mode_safe]="Safe (default minimal modules)"
MSG[menu_mode_standard]="Standard (standard setup)"
MSG[menu_mode_full]="Full (standard + optional full modules)"
MSG[menu_mode_choice]="Enter choice [1-3, default 1]: "
MSG[menu_choice_invalid]="Invalid choice. Using safe by default."
MSG[menu_mode_selected]="Selected mode:"
MSG[menu_summary]="PIPELINE SUMMARY"
MSG[menu_ok]="OK"
MSG[menu_fail]="FAIL"
MSG[menu_skip]="SKIP"
MSG[menu_finished]="Pipeline finished:"
MSG[menu_write_error]="WARNING: Cannot write summary to log"
MSG[menu_exit]="Exit"
