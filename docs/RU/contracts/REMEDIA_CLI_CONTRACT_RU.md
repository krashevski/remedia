# 🧠 REMEDIA CLI CONTRACT v1 (SPEC)

## 🎯 0. ЦЕЛЬ

Создать **единый контракт выполнения команд**, где:
- UI НЕ знает engine деталей
- CLI НЕ дублирует UI
- ENGINE не парсит строки пользователя
- каждый слой имеет ОДНУ ответственность

## 🧩 1. СЛОИ АРХИТЕКТУРЫ

### 1.1 USER LAYER (UI)
```bash
screen_system → main_menu → selection
```

✔ вызывает ТОЛЬКО:
```bash
remedia system <command> <verb>
```

❌ запрещено:
* system_doctor_verify
* system_manifest_generate

### 1.2 CLI LAYER (ENTRYPOINT)
```bash
remedia system doctor verify
```

✔ единственный публичный API

### 1.3 ROUTER LAYER (cmd_system_ui / cmd_system)
Отвечает только за:
* parsing
* dispatch
* no logic

### 1.4 ENGINE LAYER
```bash
system_doctor_verify
system_manifest_generate
system_symlinks_run
```

✔ чистая логика
✔ без CLI parsing
✔ без UI calls

## 🧾 2. ЕДИНЫЙ CLI GRAMMAR

✔ Canonical format:
```bash
remedia <module> <action> <verb> [args...]
```

✔ Examples:
```bash
remedia system doctor verify
remedia system doctor plan
remedia system doctor restore

remedia system manifest generate /path
remedia system manifest register /src /manifest

remedia system symlinks run
```

## 🧠 3. ПРИНЦИПЫ ЖЁСТКОЙ ИЗОЛЯЦИИ

❌ Запрещено:
UI → engine
engine → CLI parsing
router → business logic
UI → internal functions
✔ Разрешено:
```bash
UI → CLI → ROUTER → ENGINE
```

## 🧷 4. ПРАВИЛО ЕДИНОГО ИСТОЧНИКА ИСТИНЫ

* CLI — единственный публичный контракт
* ENGINE — единственный источник логики
* ROUTER — единственный слой маршрутизации
* UI — только взаимодействие с пользователем
