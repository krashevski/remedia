# REINCARNATION BACKUP KIT (backupkit)

[🇬🇧 English](README_BACKUPKIT_EN.md) | [🇷🇺 Russian](../RU/README_BACKUPKIT_RU.md)

**REINCARNATION BACKUP KIT (backupkit)** is a complete set of tools for backing up and restoring system and user data, even when reinstalling Ubuntu on an SSD.

## Features

- Firefox profile backup
- Backup and restore user data - home directories (`/home/...`), documents, and personal data.
Backup and restore the same version of the system - system configuration, package lists, repositories.
- Cron automation
- Log cleaning utility
- Language switching interface

## Supported operating systems:
- Debian 12
- Ubuntu 22.04 / 24.04 / 25.10

## 🔧 REINCARNATION BACKUP KIT (backupkit) requirements

- Bash 5+
- rsync
- tar / gzip
- GNOME Terminal (recommended)
- `/mnt/backups` mounted filesystem partition

## 🚀 Quick usage

```bash
git clone https://github.com/krashevski/remedia.git
cd remedia
sudo ./install.sh

# Running
backupkit
```

## 📜 Available scripts

- `backup-system.sh` - backup system settings and packages (shell).
- `backup-ubuntu-22.04.sh` — archiving Ubuntu 22.04 packages and configurations.
- `backup-ubuntu-24.04.sh` — archiving Ubuntu 24.04 packages and configurations.
- `backup-ubuntu-25.10.sh` — archiving Ubuntu 25.10 packages and configurations.
- `backup-debian-12.sh` — archiving Debian 12 packages and configurations.
- `restore-system.sh` - universal system restore (shell).
- `restore-ubuntu-22.04.sh` - restore for Ubuntu 22.04.
- `restore-ubuntu-24.04.sh` - restore for Ubuntu 24.04.
- `restore-ubuntu-25.10.sh` - restore for Ubuntu 25.10.
- `restore-debian-12.sh` — restore for Debian 12.
- `backup-restore-userdata.sh` — carefully backup or restore user data.
- `backup-userdata.sh` - backup user data (wrapper for backup-restore-userdata.sh).
- `restore-userdata.sh` - secure data recovery (wrapper for backup-restore-userdata.sh).
- `add-cron-backup.sh` - adds a cron job for daily backups.
- `cron-backup-userdata.sh` - archives user data to /mnt/backups/user_data/.
- `remove-cron-backup.sh` - removes the backup cron job.
- `clean-backup-logs.sh` - deletes old backup logs.

## ⚖️ License

MIT License © 2025 Vladislav Krashevsky

## 📬 Contact and Support

Author: Vladislav Krashevsky
Support: ChatGPT + project documentation

## See also

- MEDIA SYSTEM (mediasystem) [README_MEDIASYSTEM_EN.md](README_MEDIASYSTEM_EN.md)
- PRODUCTION MEDIA PANEL (mediopanel) [README_MEDIAPANEL_EN.md](README_MEDIAPANEL_EN.md)
- REINCARNATION MEDIA (remedia) [../../README.md](../../README.md)
