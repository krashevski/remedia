# 🔧 REMEDIA RUNTIME CONTRACT (BASH SYSTEMD STYLE SPECIFICATION)

REMEDIA RUNTIME CONTRACT v1
--------------------------------------------------
This file defines the execution guarantees, environment,
and lifecycle rules for ALL REMEDIA components
-------------------------------------------------

## 🧠 1. BASIC PRINCIPLE (SYSTEM INVARIANT)

- The kernel is immutable
- The environment defines the environment
- Modules are stateless executors
- No component can hardcode filesystem paths

## ⚙️ 2. ENVIRONMENT CONTRACT (PORTABLE VARIABLES)

### REQUIRED VARIABLES
- MODE # system
- INSTALLATION MODE # deb
- PREFIX # allowed root prefix
- REMEDIA_LIB
- REMEDIA_BIN
- REMEDIA_VAR
- REMEDIA_LOG

### RULES
- MODE is determined (never manually trusted)
- PREFIX is determined from MODE
- REMEDIA_* is determined from PREFIX
- modules are NOT MUST change ENV

## 📦 3. FILE SYSTEM CONTRACT

### SYSTEM MODES

```bash
/usr/bin/remedia
/usr/lib/remedia
/etc/remedia
/var/log/remedia
```

## 🧱 4. KERNEL CONTRACT

THE KERNEL MUST:
- reside in /usr/lib/remedia/core
- never depend on INSTALL_MODE
- never perform I/O outside runtime paths
- never use sudo
- never assume the filesystem layout

## ⚙️ 5. RUNTIME CONTRACT

THE RUNTIME MUST:
- define MODE
- define PREFIX
- generate REMEDIA_* paths
- guarantee the existence of the directory
- be The ONLY place where paths are defined

> [!] ✔ RULE
> [!] Only runtime_init() can create filesystem state.

## 🧩 6. MODULE CONTRACT

MODULES MUST:
- use REMEDIA_* variables ONLY
- do not run /usr/lib directly
- do not evaluate paths
- do not determine the environment
- do not call sudo

## 🔥 8. EXECUTION CONTRACT (RUNTIME THREAD)

```text
ENTRY POINT (/usr/bin/remedia)
↓
core/bootstrap
↓
runtime_init()
↓
resolve_mode()
↓
init_paths()
↓
cli_parse()
↓
run_pipeline()
↓
module execution
```

## 🧠 9. EXECUTOR CONTRACT

safe_run():
- never crashes the system
- Logs errors
- Returns only an error code

run_as_root():
- Raises only at the execution boundary
- Never used inside modules

## ⚠️ 10. CONTRACT ERRORS

The system MUST NEVER:
- Write to /usr at runtime
- Execute a module without runtime_init

## 🔒 11. IMMUNABILISM RULES

- CORE is read-only after installation
- Runtime state is ephemeral
- Modules are replaceable

## 🧠 12. MENTAL MODEL (KEY)

* CORE = engine (never changes)
* RUNTIME = brain (environment decides)
* MODULES = muscles (execute tasks)
* FILESYS = result of a runtime decision

## 🚀 13. SYSTEM WARRANTY

If a contract Compliance:

✔ .deb maintains itself
✔ The path is always advantageous
✔ Modules are not defined upon installation
✔ Bootstrap is always stable
