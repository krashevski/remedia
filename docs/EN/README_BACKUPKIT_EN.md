# Remedia Backup Kit

[🇬🇧 English](README_BACKUPKIT_EN.md) | [🇷🇺 Russian](../RU/README_BACKUPKIT_RU.md)

## Backup Kit User Home

**Remedia Backup Kit (REBK)** is a Linux user data backup and recovery system designed for rapid incremental archiving, a verifiable backup history, and predictable recovery.
Instead of creating a full archive of the home directory every time it runs, Backup Kit employs **differential incremental TAR archiving**.
Each new archive contains only the changes relative to its parent archive. The relationships between full and differential backups form a **dependency graph**, allowing the system to track the state from which each subsequent archive originates.
This significantly reduces the volume of redundant data storage and accelerates regular backup operations.
Periodically, a new **full snapshot of the user directory is created using `rsync`**. This serves as the new baseline for the subsequent chain of fast differential archives.
Thus, Backup Kit combines two approaches:
- periodic full backups;
- fast incremental TAR archives in between.

### Integrity Verification

Backup verification is built directly into the archiving process.
The built-in **Doctor** analyzes the archive graph and checks the status of parent backups. If a parent archive is missing or corrupt, or if the dependency chain is broken, the system reports the issue and does not consider that branch fully valid.
This ensures the user has not merely a collection of archive files, but a controlled and verifiable backup history.

### User Home Recovery

Backup Kit supports the recovery of the user's home directory.
During recovery, the system utilizes the backup structure to sequentially reconstruct the required chain, starting from the full archive and proceeding to the selected incremental state. This allows the User Home to be restored not only from the latest full snapshot but also from a state constructed using subsequent differential archives.

### Core Concept

Remedia Backup Kit is built on the following principle:
**Full backup → Differential archives → Graph validation → Restore**
Full snapshots provide a reliable baseline, fast differential TAR archives capture changes, a graph defines the relationships between archives, and a built-in "Doctor" tool continuously monitors the restore chain's integrity.
The result is a backup process that remains fast for daily use while maintaining the verifiable structure needed for reliable user environment restoration.

## Firefox Backup

Remedia Backup Kit also includes dedicated tools for backing up Firefox.
These allow you to:
- archive the Firefox profile;
- create a portable HTML file of Firefox bookmarks;
- restore a saved profile;
- save bookmarks independently of the full User Home archive.
This is particularly useful after reinstalling Linux or restoring the user environment on a new system.

## 🔧 Remedia Backup Kit Requirements

- Bash 5+
- rsync
- tar / gzip
- GNOME Terminal (recommended)
- `/mnt/backups` mounted filesystem partition

## ⚖️ License

MIT License © 2025 Vladislav Krashevsky

## ⚖️ License

MIT License © 2025 Vladislav Krashevsky

## 📬 Contact and Support

Author: Vladislav Krashevsky
Support: ChatGPT + project documentation

## See also

- MEDIA SYSTEM [README_MEDIASYSTEM_EN.md](README_MEDIASYSTEM_EN.md)
- PRODUCTION MEDIA PANEL [README_MEDIAPANEL_EN.md](README_MEDIAPANEL_EN.md)
- REMEDIA [README.md](../../README.md)
