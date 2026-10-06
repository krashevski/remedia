# SSD + HDD partitioning for Linux (optimized for editing in Shotcut)

[🇬🇧 English](README_SSD_SETUP_EN.md) | [🇷🇺 Русский](../RU/README_SSD_SETUP_RU.md)  | [🇰🇿 Қазақ тілі](../KZ/README_SSD_SETUP_KZ.md)

**Author:** Vladislav Krashevskiy
**Support:** ChatGPT

SSD + HDD partitioning and configuration for editing in Shotcut

---

## 📌 General idea

- **480 GB SSD** is used for the system, programs, user data, and video editing cache.
- **HDD (1–2 TB or more)** is used for storing source files and finished projects.
- A separate partition on the SSD is allocated for the **Shotcut cache** to speed up editing and keep the /home directory clean.

## 📊 Recommended partitioning for a 480 GB SSD

| Partition / Mount point | Size | FS | Purpose |
|----------------------------|----------|------------------------------------------------------------------------|
| `/boot/efi` | 512 MB | FAT32 | EFI boot (if using UEFI). |
| `/` (root) | 50 GB | ext4 | System and programs. |
| `swap` | 8 GB | swap | 16 GB of RAM is enough. For hibernation, set = RAM. |
| `/home` | 180 GB | ext4 | User home directories, settings, documents, small data. |
| `/mnt/shotcut` | 240 GB | ext4 | Shotcut working directory (caches, proxies, temporary renders). |
| **Total** | ~478 GB | | There is a small reserve for SSD service blocks. |

> [!] Important: If you are installing Ubuntu in UEFI+GPT motherboard mode, a special ESP (EFI System Partition) is required; it must be marked correctly in the installer.
When installing Ubuntu:
1. On the SSD (e.g. /dev/sdc1), select EFI System Partition (or "Bootable EFI") in the Use as drop-down list.
2. At the bottom, in the Device for bootloader installation field, specify the entire SSD drive (/dev/sdc), not the partition.
Post-installation check:
> [!] In BIOS/UEFI+GPT, configure the boot order so that the SSD (sdc) is first.
> [!] For UEFI+GPT mode, disable Legacy+MBR mode support in BIOS/UEFI.

## 📂 HDD (e.g. 1–2 TB)

| Mount point | Destination |
|---------------------------------------------|----------------------------------|
| `/mnt/storage` (on the third hard drive) | Source files (video, photos, music). |
| `/home/user2` (on the third hard drive) | for user2 if is. |
| `/mnt/backups` (on the second hard drive) | Archive of old projects, backups. |

> [!] An external USB hard drive is not suitable for backing up user data due to its slow performance.

## 🛠 Shotcut Setup

> [I] The `install_media_tools.sh` script will automatically configure all the necessary settings.
1. You can install an SSD in the **Default project folder** (it's faster during work), and transfer finished projects to the HDD.
2. In the Settings → Proxy → Storage and Settings → Cache → Storage menus, specify the path /mnt/shotcut.
3. Source files (videos, photos, music) and exported files are always stored on the HDD.

## ✅ Advantages of this setup

1. The system and programs are fast (the / partition is separate).
2. Shotcut's cache doesn't clog up /home and is easy to clean.
3. The HDD is used exclusively for storing large files, without consuming the SSD.
4. You can run several large projects simultaneously.
5. "Set it and forget it" balance—no constant battle for space.

## 🔑 Minimum SSD sizes for comfortable work

- **80–100 GB** is the starting minimum (you need to be very disciplined about moving all heavy files to the HDD).
- **120–128 GB** — comfortable for the system + /home (but the cache will have to be stored on the HDD).
- **240–256 GB** — space can be allocated for the Shotcut cache, but the amount is limited.
- **480 GB** — optimal balance: system, users, and installation on the SSD, data on the HDD.

## See also

- For operating system reinstallation, see [README_REINSTALL_SYSTEM_EN.md](README_REINSTALL_SYSTEM_EN.md)
- For connecting a second disk in Linux, see [README_DISK_EN.md](README_DISK_EN.md)
- Shotcut settings for quick editing and export [README_SHOTCUT_EN.md](README_SHOTCUT_EN.md)
- For installation and usage of Backup Kit, see [README_ALL_EN.md](README_ALL_EN.md)
