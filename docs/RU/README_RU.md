# REMEDIA

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Создано с помощью Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)
[![Размер репозитория GitHub](https://img.shields.io/github/repo-size/krashevski/reincarnation-backup-kit)](https://github.com/krashevski/reincarnation-backup-kit)
[![Звезды GitHub](https://img.shields.io/github/stars/krashevski/reincarnation-backup-kit)](https://github.com/krashevski/reincarnation-backup-kit)

[🇬🇧 Английский](README.md) | [🇷🇺 Русский](docs/RU/README_RU.md)

**Remedia** — это модульная системная среда для Debian/Ubuntu, ориентированная на:
* медиа-производство
* восстановление системы
* контроль целостности
* безопасную работу с пакетами
Remedia объединяет CLI-фреймворк, runtime, registry и модульную архитектуру в единую инженерную систему.

## ✨ Основные идеи

Remedia возник не как абстрактный инструмент, а как ответ на реальные проблемы Linux-систем:
* повреждение прав и ownership
* неконтролируемые postinstall-скрипты
* загрязнение системы после удаления пакетов
* отсутствие безопасного staging перед установкой
* сложность восстановления рабочего окружения

Проект развивается в сторону:
* **transactional system behavior**
* **manifest-driven state**
* **recovery-first architecture**
* **runtime isolation**
* **modular CLI orchestration**

## 🧱 Архитектура

Remedia — это не просто набор скриптов. Это многослойная система:
```text
remedia 
├── CLI (entrypoint router) 
├── Runtime (execution environment) 
├── Registry (modules + contracts) 
├── Modules 
│ ├── system 
│ ├── mediasystem 
│ ├── mediapanel 
│ ├── backupkit 
│ └── demo 
└── Config (/etc/remedia)
```

## 🚀 Установка

```bash
sudo dpkg -i remedia_1.0.0_all.deb
```

Зависимости:
* bash >= 5.0
* coreutils
Рекомендуется:
* util-linux
* findutils

## 🖥 Использование
### CLI
```bash
remedia
```

### Запуск UI
```bash
remedia system center
```

## 🧩 Ключевые компоненты

### MediaSystem
Pipeline-ориентированная система для медиа-производства.

### MediaPanel
Интерфейс управления медиа-средой и workflow.

### BackupKit (Reincarnation)
Система восстановления пользовательских данных и состояния системы.

### System Tools
Набор инструментов диагностики, контроля и обслуживания.

## ⚙️ Конфигурация

Основной конфиг:
```bash
/etc/remedia/remedia.env
```

## 🧠 Manifest Model

Remedia вводит **manifest-driven модель состояния системы**.
Manifest:
* фиксирует ожидаемое состояние
* используется как **trust anchor**
* помогает восстановлению при деградации системы

## 🔍 Remedia Doctor (планируется)

Глобальная диагностика системы:
```bash
remedia doctor
```

Пример:
```text
dpkg      → OK
home      → OK
disk      → WARN
gpu       → SKIPPED

SYSTEM HEALTH: 92%
```

## 🔐 Философия

Remedia — это слой между пакетом и системой.
Он добавляет:
* проверку перед установкой
* контроль файловой системы
* изоляцию выполнения
* возможность анализа пакета до применения
Это приближает систему к:
* sandbox inspection
* deployment simulation
* reproducible environments

## 🎬 Истоки проекта

Проект вырос из:
* работы с видео (Shotcut)
* необходимости стабильной среды
* повторяющихся восстановлений системы
* накопленного опыта эксплуатации Linux

Сначала появился **Reincarnation Backup Kit**,
затем выделился **Media System**,
и в итоге сформировался **Remedia** как целостная система.

## 📜 Контакты и поддержка

Автор: Владислав Крашевский 📧 v.krashevski@gmail.com
Поддержка: ChatGPT

## 📌 Статус

Версия: **1.0.0**
Проект находится в стадии активного развития:
* стабилизация контрактов
* улучшение runtime
* развитие UI
* внедрение transactional моделей

## 🧭 Направление развития

* полноценный staging перед установкой пакетов
* rollback и snapshot система
* расширение doctor subsystem
* развитие Media Panel
* повышение отказоустойчивости

## 🤝 Вклад

На текущем этапе проект развивается автором.
В будущем планируется открытие для контрибьюторов.

## ⚠️ Важно

Remedia работает с системными компонентами.
Рекомендуется:
* использовать с пониманием Linux-систем
* тестировать в безопасной среде
* делать резервные копии

## 📎 Заключение

Remedia — это попытка сделать Linux-среду:
* устойчивой
* предсказуемой
* восстанавливаемой
* пригодной для длительной работы

Не просто «чтобы работало», а **чтобы переживало сбои и время**.
