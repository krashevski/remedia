# 🧩 MEDIASYSTEM MODULE CONTRACT v1

## 1. 📦 REQUIRED MODULE HEADER

```bash
#!/usr/bin/env bash
# <module_name>.sh

set -euo pipefail

: "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once
```

## 2. 🚫 PROHIBITED IN SUBMODULES

❌ You cannot:
- declare -p (debug dump)
- set -x in production
- echo instead of logs (except fatal) bootstrap cases)
- exit 100 / custom codes without standard
- unprotected rm
- apt install without error checking
- global "quiet" || true without reason

## 3. 🧠 STANDARD EXECUTION FLOW

Each module must follow the following order:
1. init
2. guards (dependencies / environment)
3. mode checks (SAFE / PIPELINE_MODE)
4. start log
5. execution
6. error handling
7. finish log

## 4. 🔐 SAFE MODE RULE

```bash
if [[ "${SAFE_MODE:-0}" -eq 1 ]]; then
    log_info "Skipping module (SAFE_MODE)"
    exit 0
fi
```

- SAFE_MODE is always the main override
- never ignored

## 5. ⚙️ PIPELINE MODE RULE

```bash
PIPELINE_MODE="${PIPELINE_MODE:-default}"
```

Default:
```text
| mode | behavior |
| -------- | ------------------ |
| safe | minimal changes |
| standard | normal install |
| full | aggressive install |
```

## 6. 📡 GPU / SYSTEM PROTECTION

GPU check:
```bash
if command -v lspci >/dev/null 2>&1; then
    if lspci | grep -qi nvidia; then
        GPU="nvidia"
    else
        GPU="none"
    fi
else
    log_warn "lspci not available"
    GPU="unknown"
fi
```

## 7. 🧾 LOGGING RULES

Always:
```bash
log_info "=== Starting $MODULE_NAME ==="
```

Completion:
```bash
log_info "=== Completed $MODULE_NAME ==="
```

❌ You cannot:
- duplicate the module name manually
- use `echo` instead of `log_`

## 8. 💥 ERROR HANDLING RULES

Correct pattern:
```bash
if ! some_command; then
    log_error "Operation failed"
    exit 1
fi
```

❌ Forbidden:
```bash
some_command || log_error ...
```

(breaks with set -e)

## 9. 📦 PACKAGE INSTALLATION RULES

Default:
```bash
if ! sudo apt install -y package; then
    log_error "Install failed"
    exit 1
fi
```

## 10. 🧱 MODULE EXIT POLICY

```text
| case                    | exit     |
| ----------------------- | -------- |
| success                 | 0        |
| skip (SAFE_MODE)        | 0        |
| skip (feature disabled) | 0        |
| dependency missing      | 0 (warn) |
| real failure            | 1        |
```

## 11. 🚫 FORBIDDEN PATTERNS

❌ forbidden:
```bash
exit 100
exit 2 (custom meaning)
```

## 12. 📁 DIRECTORY RULE

Always:
```bash
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

## 13. ⚙️ CONFIGURATION PRIORITIES (IMPORTANT)

Variable priority:
```bash
SAFE_MODE (highest override)
↓
PIPELINE_MODE
↓
MODULE FLAGS (ENABLE_X)
↓
defaults
```

## 14. 🧪 DEPENDENCY RULE

Before use:
```bash
command -v <tool> >/dev/null 2>&1 || {
    log_warn "missing dependency: <tool>"
    exit 0
}
```

## 15. 🧭 STANDARD MODULE TEMPLATE (MASTER)

```bah
#!/usr/bin/env bash
# module.sh

set -euo pipefail

: "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

# SAFE MODE
if [[ "${SAFE_MODE:-0}" -eq 1 ]]; then
    log_info "Skipping module (SAFE_MODE)"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

# GUARDS
command -v some_tool >/dev/null 2>&1 || {
    log_warn "dependency missing: some_tool"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
}

# MODE LOGIC
PIPELINE_MODE="${PIPELINE_MODE:-default}"

# EXECUTION
if ! some_command; then
    log_error "Execution failed"
    exit 1
fi

log_info "=== Completed $MODULE_NAME ==="
```

## 🧠 MAIN IDEA OF THE CONTRACT

You don't write “bash scripts” anymore.
You write:
> managed execution units for pipeline runtime

## 🚀 IN SUMMARY

- uniform module style
- predictable pipeline
- error checking
- SAFE_MODE as a global override
- GPU/system guards
- identical exit semantics

## 💥 MOST IMPORTANT

Now you have:
> **a single execution contract, not a set of scripts**
