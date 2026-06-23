# MEDIA SYSTEM (mediasystem)

[🇬🇧 English](README_MEDIASYSTEM_EN.md) | [🇷🇺 Russian](../RU/README_MEDIASYSTEM_RU.md)

## Overview

The **MEDIA SYSTEM (mediasystem)** system is used to manage media processing software installation pipelines in Linux environments.

The main pipeline script, `mediasystem.sh`, manages all modules in the correct order and provides correct logging.

## Features

- Automatic installation of required packages (APT, Flatpak, etc.)
- Modular pipeline with independent stages
- Easy setup of user-defined media program directories
- Centralized log processing with timestamps
- Secure uninstallation with `uninstall_mediasystem.sh`

## Requirements

- Linux-based system (Debian/Ubuntu recommended)
- Bash 5.1+
- Essential utilities: `grep`, `xargs`, `tar`
- Optional: `sudo` access for package installation

## Using the `mediasystem` pipeline

The pipeline will perform the following actions:
- Update APT repositories and install the necessary base system and video packages.
- Check GPU usage, install and configure the Nvidia driver and the Cuda toolkit, check GPU support by the ffmpeg package, and check OpenGL functionality.
- Install APT applications as directed.
- Install Flatpak applications as directed.
- Install SNAP applications as directed.
- Check Shotcut's GPU support.
- Generate a summary log in `logs/`.

### Interactive log mode selection:
- Safe — minimal changes, suitable for testing
- Standard — installs modules required for the Shotcut video editor
- Full — installs all Ubuntu/Linux media production software as directed.

### Logging:
All output is written to the file /var/log/remedia/mediasystem/pipeline.log. Check this file if any modules are not working. Example:
```bash
/var/log/remedia/mediasystem/
├── pipeline.log
├── 60_apt_packages.log
├── 10_snap_packages.log
└── 00_detect_gpu.log
```

### Pipeline Feature
When running `mediasystem.sh`, the user can choose the mode interactively or set it in the environment:
```bash
export PIPELINE_MODE=full ./mediasystem.sh
```

### Removing the `mediasystem` pipeline

To safely remove installed packages, Flatpak applications, and configuration files:
```bash
./uninstall_mediasystem.sh
```

- Automatically removes APT packages listed in `packages/apt/`.
- Removes Snap and Flatpak applications, if present.
- Cleans up configuration files for Shotcut and OBS Studio.
> [!] The uninstall script runs in safe mode by default, so resource-intensive or optional modules may be skipped.

## Ubuntu vs. Debian

| OS | First Run Notes | Common Problems and Solutions |

| ----------- | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |

| **Ubuntu** | - Usually contains up-to-date packages. <br> - Run with `sudo` when installing system packages. | - LTS versions may be missing some older dependencies. <br> - Make sure `curl`, `wget`, `git`, and `build-essential` are installed. |

| **Debian** | - The standard stable version may be older; enabling `backports` may be required. <br> - Use `sudo` for APT commands. | - Missing dependencies (e.g. `python3-venv`, `ffmpeg`) often require manual installation. <br> - Some modules may not work on older library versions. |

### Quick setup tips for both systems:
```bash
# Update the system first
sudo apt update && sudo apt upgrade -y

# Install the necessary tools
sudo apt install -y curl wget git build-essential python3-venv

# Optional: Enable backports support in Debian for new packages
# echo "deb http://deb.debian.org/debian $(lsb_release -cs)-backports main" | sudo tee -a /etc/apt/sources.list
```

> 💡 Tip: The `/usr/local/bin/mediasystem` script logs progress and automatically handles most errors. On Debian, if the module doesn't work due to missing libraries, install the required packages manually and run the script again.

## Configuration

- APT packages and applications: `packages/apt_utils.txt` `packages/apt_media.txt` (one package per line, comments allowed)
- Flatpak applications: `packages/flatpak.txt`
- SNAP applications: `packages/snap.txt`

## Troubleshooting

- If a module doesn't work, check the corresponding log file in $LOG_DIR.
- Make sure sudo is available to install packages.
- Make sure Flatpak is installed and configured correctly on your system.
- Check online that the package for your OS version is supported by APT or SNAP.
- If you have problems uninstalling, make sure PIPELINE_MODE is set to safe (the uninstall script does this automatically).

## Contributions

- Add modules to `modules/`
- Use standard logging functions (`log_info`, `log_warn`, `log_error`)
- Submit pull requests for review

## License

MIT License © 2025 Vladislav Krashevsky

## Contact and Support

Author: Vladislav Krashevsky
Support: ChatGPT and project documentation

## See also

- PRODUCTION MEDIA PANEL (mediapanel) [README_MEDIAPANEL_EN.md](README_MEDIAPANEL_EN.md)
- REINCARNATION BACKUP KIT (backupkit) [README_BACKUPKIT_EN.md](README_BACKUPKIT_EN.md)
- REINCARNATION MEDIA (remedia) [../../README_EN.md](../../README_EN.md)
