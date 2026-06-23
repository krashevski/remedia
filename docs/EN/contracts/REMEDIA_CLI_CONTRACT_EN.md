# 🧠 REMEDIA CLI CONTRACT v1 (SPEC)

## 🎯 0. GOAL

Create a **single command execution contract**, where:
- The UI does not know engine details
- The CLI does not duplicate the UI
- The ENGINE does not parse user strings
- Each layer has ONE responsibility

## 🧩 1. ARCHITECTURE LAYERS

### 1.1 USER LAYER (UI)
```bash
screen_system → main_menu → selection
```

✔ Calls ONLY:
```bash
remedia system <command> <verb>
```

❌ Disables:
* system_doctor_verify
* system_manifest_generate

### 1.2 CLI LAYER (ENTRYPOINT)
```bash
remedia system doctor verify
```

✔ Single public API

### 1.3 ROUTER LAYER (cmd_system_ui / cmd_system)
Responsible only for:
* parsing
* dispatch
* no logic

### 1.4 ENGINE LAYER
```bash
system_doctor_verify
system_manifest_generate
system_symlinks_run
```

✔ Pure logic
✔ No CLI parsing
✔ No UI calls

## 🧾 2. SINGLE CLI GRAMMAR

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

## 🧠 3. HARD ISOLATION PRINCIPLES

❌ Prohibited:
UI → engine
engine → CLI parsing
router → business logic
UI → internal functions
✔ Allowed:
```bash
UI → CLI → ROUTER → ENGINE
```

## 🧷 4. SINGLE SOURCE OF TRUTH RULE

* CLI — single public contract
* ENGINE — single source of logic
* ROUTER — single routing layer
* UI — user interaction only
