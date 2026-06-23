# Подключение второго диска под Linux

[🇬🇧 English](../EN/README_DISK_EN.md) | [🇷🇺 Русский](README_DISK_RU.md)

**Автор:** Владислав Крашевский
**Поддержка:** ChatGPT

Этот README описывает процесс подключения второго диска в Linux (например, для хранения резервных копий).

> [!] Внешний USB твёрдый диск из-за медленной работы не подходит для создания резервных копий пользовательских данных.

## 🔍 1. Определение диска

Смотрим список дисков и разделов:

```bash
lsblk -f
```

или
```bash
sudo fdisk -l
```

Пример вывода:
```bash
sda      ext4   Ubuntu-Root
sdb
└─sdb1   ext4   backups
```

> [i] Здесь sdb1 — это раздел второго диска.

## 💾 2. Создание файловой системы (только для нового диска!)

> [!} ⚠️ Внимание: эта операция удалит все данные на разделе!
Создать файловую систему ext4:
```bash
sudo mkfs.ext4 /dev/sdb1
```

## 📂 3. Временное монтирование

Создаём каталог для монтирования и подключаем раздел:
```bash
sudo mkdir -p /mnt/backups
sudo mount /dev/sdb1 /mnt/backups
```

> [i} Теперь диск доступен по пути /mnt/backups.

## ⚙️ 4. Автоматическое монтирование при загрузке

Чтобы диск монтировался автоматически, нужно добавить его в /etc/fstab.
Узнаём UUID раздела:
```bash
sudo blkid /dev/sdb1
```

Пример вывода:
```bash
UUID="df4ca060-a835-463a-8a58-1e34ee8c39db" TYPE="ext4"
```

1. Редактируем файл:
```bash
sudo nano /etc/fstab
```

2. Добавляем строку:
```bash
UUID=df4ca060-a835-463a-8a58-1e34ee8c39db   /mnt/backups   ext4   defaults   0   2
```

3. Проверяем корректность:
```bash
sudo mount -a
```

## 👤 5. Настройка прав доступа

Чтобы пользователь мог работать с диском:
```bash
sudo chown -R $USER:$USER /mnt/backups
```

## 🔧 6. Использование с Backup Kit

Все скрипты Backup Kit используют переменную:
```bash
BACKUP_DIR="/mnt/backups"
```

> [i] После подключения и настройки диска бэкапы будут сохраняться автоматически в /mnt/backups.

## См. также

- SSD + HDD разметка для Linux (под монтаж в Shotcut) см. файл [README_SSD_SETUP_RU.md](README_SSD_SETUP_RU.md)
- Переустановка операционной системы см. файл [README_REINSTALL_SYSTEM_RU.md](README_REINSTALL_SYSTEM_RU.md)
- Backup Kit — Установка и Использование см. файл [README_ALL_RU.md](README_ALL_RU.md)


