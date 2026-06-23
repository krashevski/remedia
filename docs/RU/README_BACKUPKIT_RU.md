# REINCARNATION BACKUP KIT (backupkit)

[🇬🇧 English](../EN/README_BACKUPKIT_EN.md) | [🇷🇺 Русский](README_BACKUPKIT_RU.md)

**REINCARNATION BACKUP KIT (backupkit)** — полный набор инструментов для резервного копирования и восстановления системных и пользовательских данных, также при переустановке **Ubuntu** на SSD.

## Возможности

- резервное копирование профиля Firefox
- резервное копирование и восстановление пользовательских данных  — домашние каталоги (`/home/...`), документы и личные данные.
резервное копирование и восстановление системы той же версии — конфигурация системы, списки пакетов, репозитории.
- автоматизация cron
- утилита очистки логов
- интерфейс переключения языков

## Поддерживаемые операционные системы:
- Debian 12
- Ubuntu 22.04 / 24.04 / 25.10

## 🔧 Требования REINCARNATION BACKUP KIT (backupkit)

- Bash 5+
- rsync
- tar / gzip
- GNOME Terminal (рекомендуется)
- `/mnt/backups` смотированный раздел файловой системы

## 🚀 Быстрое использование

```bash
git clone https://github.com/krashevski/remedia.git
cd remedia
sudo ./install.sh

# Запуск
backupkit
```

## 📜 Доступные скрипты

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

## ⚖️ Лицензия

Лицензия MIT © 2025 Владислав Крашевский

## 📬 Контакты и поддержка

Автор: Владислав Крашевский
Поддержка: ChatGPT + документация проекта

## Смотри также

- MEDIA SYSTEM (mediasystem) [README_MEDIASYSTEM_RU.md](README_MEDIASYSTEM_RU.md)
- PRODUCTION MEDIA PANEL (medipoanel) [README_MEDIAPANEL_RU.md](README_MEDIAPANEL_RU.md)
- REINCARNATION MEDIA (remedia) [README_RU.md](README_RU.md)
