# PRODUCTION MEDIA PANEL (mediapanel)

[🇬🇧 English](README_MEDIAPANEL_EN.md) | [🇷🇺 Russian](../RU/README_MEDIAPANEL_RU.md)

**PRODUCTION MEDIA PANEL (mediapanel)** is an interactive Linux panel for managing video projects, importing video from your phone, creating proxy files, editing, exporting, and archiving.

Designed for documentary and creative projects.

## Key Features

1. **System Status** – Displays GPU, NVENC, available space, and the number of projects.
2. **Project Information** – Displays:
- Number of clips in `footage`
- Number of proxy files
- Folder size
- General project statistics, last modified date, and lifecycle stage
3. **Create Project** – Creates a project in two locations:
- Storage: `/mnt/storage/Videos/projects/ProjectName`
- Shotcut: `/home/user/shotcut/projects/ProjectName`
4. **Upload Videos from Phone** – Import videos from your phone:
- Originals in `raw` format
- Working files in `footage` format
5. **Create Proxy** – Creates proxy files in the Shotcut folder with UTF-8 encoding and security settings.
6. **Run Shotcut** – Opens Shotcut (Flatpak).
7. **Export to YouTube** – Exports the finished video to the `exports` folder with YouTube settings.
8. **Archive Project** – saves the video project to a .tar.gz archive.
9. **Video/Graphics/Audio Tools** – Quick access to APT, SNAP, and Flatpak applications:
- Shotcut, OBS Studio
- GIMP, Krita
- Audacity

## Project Structure

**Storage (Originals)**
/mnt/storage/Videos/projects/ProjectName
* footage/
* raw/
* edit/
* export/

**Shotcut (Workspace)**
/home/vladislav/shotcut/projects/ProjectName
* proxy/
* project/

## 🔧 PRODUCTION MEDIA PANEL (media PANEL) Requirements

- Bash 5+
- rsync
- tar / gzip
- GNOME Terminal (recommended)
- `/mnt/backups` – Mounted file system partition. This partition will store video project archives and will serve as a recycle bin. Subsequent removal of video garbage.
- `/mnt/shotcut` mounted filesystem partition for the Shotcut proxy
- `/mnt/storage` mounted filesystem partition for storing large media files (Videos, Images, and Music)

## Installing PRODUCTION MEDIA PANEL (mediaoanel)

Installation:
1. Clone this repository:
```bash
git clone https://github.com/krashevski/remedia.git
cd remedia
```

2. Run the installation:
```bash
sudo ./install.sh
```

3. Run:
```bash
remedia
```

4. In the menu, select: **Media system (installing and configuring programs)** and select: **Full (standard + all additional modules)**.
5. In the menu, select: **Media Panel (Media Production)**
6. Make sure the following APT and Flatpak media apps are installed:
- Shotcut
- OBS Studio
- GIMP
- Krita
- Audacity

## 🎬 PRODUCTION MEDIA PANEL (mediapanel) Production Workflow

Typical workflow:
- Project creation
- Import video footage (phone or storage)
- Generate proxies
- Clean up/sync audio
- Split scenes
- Edit in Shotcut
- Export (YouTube/archive)
- Automatic logging updated

## 🧠 PRODUCTION MEDIA PANEL (mediapanel) Project Lifecycle States

NEW — created but not started
IN PROGRESS — actively being edited
DONE — completed

## 🔐 PRODUCTION MEDIA Design Principles PANEL (mediapanel)

✔ Modularity
Each suite operates independently:
- No hard dependencies between modules
- Component sharing only via shared-li
✔ Fault-tolerant architecture
- set -euo pipefail is used in core scripts
- PID-based locking system in production tools
- Automatic cleaning of obsolete locks
- Secure deletion of media files via the Recycle Bin
✔ Production-focused workflow
The system is designed for:
- Long-term projects
- Workflows with large volumes of media content (4K editing)
- Non-destructive processing
- Step-by-step pipelines (RAW → EDIT → EXPORT)
✔ Logs in a human-readable format
Each project supports:
```bash
.log — Production history timeline
.status — Project status (NEW / IN PROGRESS / DONE)
.lock — Active lock protection Sessions
```

## Notes

All operations are safe for UTF-8 encoding and spaces in file names.
Proxies are created in a separate working folder, `/mnt/shotcut`, on the SSD drive to speed up editing.
Integration with Shotcut allows you to immediately use proxies for editing large 4K projects.

## License

MIT License © 2026 Vladislav Krashevsky

## Contact and Support

Author: Vladislav Krashevsky
Support: ChatGPT and project documentation

## See also

- MEDIA SYSTEM (mediasystem) [README_MEDIASYSTEM_EN.md](README_MEDIASYSTEM_EN.md)
- REINCARNATION BACKUP KIT (backupkit) [README_BACKUPKIT_EN.md](README_BACKUPKIT_EN.md)
- REINCARNATION MEDIA (remedia) [../../README_EN.md](../../README_EN.md)
